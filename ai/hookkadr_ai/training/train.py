"""Training job for HOOKKADR Vision · Scene Quality.

Reproducible by construction: fixed seeds, deterministic CPU kernels, the
dataset content hash is verified before training, and the run directory keeps
the resolved config, environment, per-epoch metrics, checkpoints, the exported
candidate artifact and its test evaluation against the rule baseline.

Usage::

    uv run python -m hookkadr_ai.training.train --config configs/scene_quality_v1.json
"""

from __future__ import annotations

import argparse
import json
import platform
import subprocess
import time
from pathlib import Path

import numpy as np
import torch
from torch import nn

from ..datasets import registry as datasets
from ..features.frame_quality import FEATURE_NAMES, FEATURE_VERSION
from ..media.ffmpeg import ANALYSIS_FILTER, ANALYSIS_LONG_SIDE
from ..models.scene_quality import ArtifactModel, SceneQualityNet, export_artifact
from ..paths import AI_ROOT, RUNS_DIR
from ..evaluation.baseline import fit_quality_rule, fit_rules
from ..evaluation.evaluate import evaluate_model, evaluate_rules
from ..evaluation.metrics import best_f1_threshold, roc_auc


def _git_commit() -> str:
    try:
        out = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=AI_ROOT, capture_output=True, text=True)
        dirty = subprocess.run(["git", "status", "--porcelain", "--", "ai/hookkadr_ai"], cwd=AI_ROOT.parent, capture_output=True, text=True)
        return out.stdout.strip() + ("+dirty" if dirty.stdout.strip() else "")
    except OSError:
        return "unknown"


def _loss(logits: torch.Tensor, yd: torch.Tensor, yq: torch.Tensor, w_q: float) -> torch.Tensor:
    bce = nn.functional.binary_cross_entropy_with_logits
    return bce(logits[:, 1:], yd) + w_q * bce(logits[:, 0], yq)


def train(config_path: Path) -> Path:
    cfg = json.loads(config_path.read_text())
    tc, mc = cfg["training"], cfg["model"]
    entry, arrays = datasets.load_verified(cfg["dataset"]["id"])
    if entry["featureVersion"] != FEATURE_VERSION or entry["features"] != list(FEATURE_NAMES):
        raise ValueError("dataset was built with a different feature version — rebuild it")
    defects: list[str] = entry["defects"]

    X, Yd, Yq, split = arrays["X"], arrays["y_defects"], arrays["y_quality"], arrays["split"]
    tr, va, te = (split == 0), (split == 1), (split == 2)
    mean = X[tr].mean(axis=0)
    std = X[tr].std(axis=0)
    std[std < 1e-6] = 1.0

    torch.manual_seed(tc["seed"])
    np.random.seed(tc["seed"])
    torch.use_deterministic_algorithms(True)
    torch.set_num_threads(1)

    def tensors(mask: np.ndarray) -> tuple[torch.Tensor, torch.Tensor, torch.Tensor]:
        return (
            torch.tensor((X[mask] - mean) / std, dtype=torch.float32),
            torch.tensor(Yd[mask], dtype=torch.float32),
            torch.tensor(Yq[mask], dtype=torch.float32),
        )

    xtr, ydtr, yqtr = tensors(tr)
    xva, ydva, yqva = tensors(va)
    net = SceneQualityNet(len(FEATURE_NAMES), mc["hidden"], len(defects))
    opt = torch.optim.AdamW(net.parameters(), lr=tc["lr"], weight_decay=tc["weightDecay"])
    gen = torch.Generator().manual_seed(tc["seed"])

    run_id = time.strftime("%Y%m%d-%H%M%S")
    run_dir = RUNS_DIR / mc["name"] / run_id
    (run_dir / "checkpoints").mkdir(parents=True, exist_ok=True)
    (run_dir / "config.json").write_text(json.dumps(cfg, indent=2))
    env = {
        "python": platform.python_version(),
        "torch": torch.__version__,
        "numpy": np.__version__,
        "platform": platform.platform(),
        "device": "cpu",
        "git": _git_commit(),
        "dataset": entry["id"],
        "datasetSha256": entry["sha256"],
        "seed": tc["seed"],
        "counts": {"train": int(tr.sum()), "val": int(va.sum()), "test": int(te.sum())},
    }
    (run_dir / "env.json").write_text(json.dumps(env, indent=2))

    best_val, best_epoch, best_state = float("inf"), -1, None
    log = (run_dir / "metrics.jsonl").open("w")
    t0 = time.time()
    for epoch in range(tc["maxEpochs"]):
        net.train()
        perm = torch.randperm(len(xtr), generator=gen)
        total = 0.0
        for i in range(0, len(perm), tc["batchSize"]):
            idx = perm[i : i + tc["batchSize"]]
            opt.zero_grad()
            loss = _loss(net(xtr[idx]), ydtr[idx], yqtr[idx], tc["qualityLossWeight"])
            loss.backward()
            opt.step()
            total += float(loss.detach()) * len(idx)
        net.eval()
        with torch.no_grad():
            lv = net(xva)
            val_loss = float(_loss(lv, ydva, yqva, tc["qualityLossWeight"]))
            pv = torch.sigmoid(lv).numpy()
        val_auc = float(np.nanmean([roc_auc(Yd[va][:, j], pv[:, 1 + j]) for j in range(len(defects))]))
        log.write(json.dumps({"epoch": epoch, "trainLoss": total / len(xtr), "valLoss": val_loss, "valMacroAuc": val_auc}) + "\n")
        if val_loss < best_val - 1e-5:
            best_val, best_epoch = val_loss, epoch
            best_state = {k: v.clone() for k, v in net.state_dict().items()}
            torch.save(best_state, run_dir / "checkpoints" / "best.pt")
        elif epoch - best_epoch >= tc["patience"]:
            break
    log.close()
    torch.save(net.state_dict(), run_dir / "checkpoints" / "last.pt")
    assert best_state is not None
    net.load_state_dict(best_state)
    net.eval()
    train_sec = time.time() - t0

    # Decision thresholds tuned on validation (never on test).
    with torch.no_grad():
        pv = torch.sigmoid(net(xva)).numpy()
    thresholds = {d: round(best_f1_threshold(Yd[va][:, j], pv[:, 1 + j]), 4) for j, d in enumerate(defects)}

    meta = {
        "name": mc["name"],
        "version": mc["version"],
        "task": "frame_quality",
        "input": {
            "featureVersion": FEATURE_VERSION,
            "features": list(FEATURE_NAMES),
            "analysisFilter": ANALYSIS_FILTER,
            "analysisLongSide": ANALYSIS_LONG_SIDE,
        },
        "defects": defects,
        "thresholds": thresholds,
        "provenance": {
            "baseModel": None,
            "architecture": f"MLP {len(FEATURE_NAMES)}-{'-'.join(map(str, mc['hidden']))}-{1 + len(defects)}, ReLU",
            "framework": f"torch {torch.__version__}",
            "dataset": entry["id"],
            "datasetSha256": entry["sha256"],
            "trainRun": f"{mc['name']}/{run_id}",
            "git": env["git"],
            "bestEpoch": best_epoch,
            "labelling": entry["labelling"],
        },
    }
    artifact = export_artifact(net, mean, std, meta=meta)
    model = ArtifactModel(artifact)

    # Parity: the exported artifact must reproduce the torch model.
    xte = torch.tensor((X[te] - mean) / std, dtype=torch.float32)
    with torch.no_grad():
        torch_p = torch.sigmoid(net(xte)).numpy().astype(np.float64)
    q_np, d_np = model.predict(X[te])
    parity = float(np.max(np.abs(np.column_stack([q_np, d_np]) - torch_p)))
    if parity > 1e-4:
        raise RuntimeError(f"artifact does not reproduce the network (max diff {parity})")

    rules = fit_rules(X[tr], Yd[tr], defects)
    q_rule = fit_quality_rule(X[tr], Yq[tr])
    report = {
        "test": evaluate_model(model, X[te], Yd[te], Yq[te]),
        "baselineTest": evaluate_rules(rules, q_rule, X[te], Yd[te], Yq[te]),
        "val": evaluate_model(model, X[va], Yd[va], Yq[va]),
        "parityMaxAbsDiff": parity,
        "bestEpoch": best_epoch,
        "trainSeconds": round(train_sec, 1),
    }
    artifact["metrics"] = {
        "test": {
            "macroAuc": report["test"]["macroAuc"],
            "macroF1": report["test"]["macroF1"],
            "qualitySpearman": report["test"]["quality"]["spearman"],
        },
        "baselineTest": {"macroAuc": report["baselineTest"]["macroAuc"], "macroF1": report["baselineTest"]["macroF1"]},
    }
    (run_dir / "artifact").mkdir(exist_ok=True)
    (run_dir / "artifact" / "model.json").write_text(json.dumps(artifact))
    (run_dir / "eval.json").write_text(json.dumps(report, indent=2))
    print(_summary(report))
    print(f"run: {run_dir.relative_to(AI_ROOT)}")
    return run_dir


def _summary(r: dict) -> str:
    t, b = r["test"], r["baselineTest"]
    lines = [f"test n={t['n']}  macroAUC model {t['macroAuc']:.3f} vs rules {b['macroAuc']:.3f}  "
             f"macroF1 {t['macroF1']:.3f} vs {b['macroF1']:.3f}  quality spearman {t['quality']['spearman']:.3f} "
             f"(rule {b['quality']['spearman']:.3f})"]
    for d, m in t["defects"].items():
        lines.append(f"  {d:13s} AUC {m['auc']:.3f} (rule {b['defects'][d]['auc']:.3f})  F1 {m['f1']:.3f} (rule {b['defects'][d]['f1']:.3f})")
    return "\n".join(lines)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--config", type=Path, required=True)
    args = ap.parse_args()
    train(args.config if args.config.is_absolute() else AI_ROOT / args.config)


if __name__ == "__main__":
    main()
