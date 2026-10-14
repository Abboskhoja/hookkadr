"""Model registry: candidates → promotion gate → production → rollback.

``registry/models.json`` and ``registry/artifacts/`` are committed. Versions
are immutable once promoted. A candidate becomes production only when the
gate passes (it beats the rule baseline, its quality ranking is good enough,
and it does not regress against the current production model on the same
test data). Promotion and rollback also export the production artifact to the
Flutter app (``assets/models``) together with parity goldens for Dart tests.

Usage::

    uv run python -m hookkadr_ai.registry.model_registry register --run runs/scene_quality/<id>
    uv run python -m hookkadr_ai.registry.model_registry promote --model scene_quality --version 1.0.0
    uv run python -m hookkadr_ai.registry.model_registry rollback --model scene_quality
    uv run python -m hookkadr_ai.registry.model_registry list
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import time
from pathlib import Path

from ..datasets import registry as datasets
from ..evaluation.evaluate import evaluate_model
from ..models.scene_quality import ArtifactModel
from ..paths import AI_ROOT, CONFIGS_DIR, REGISTRY_DIR
from . import app_export
from .model_card import write_card

REGISTRY = REGISTRY_DIR / "models.json"
ARTIFACTS = REGISTRY_DIR / "artifacts"


def _load() -> dict:
    return json.loads(REGISTRY.read_text()) if REGISTRY.exists() else {"models": {}}


def _save(data: dict) -> None:
    REGISTRY.parent.mkdir(parents=True, exist_ok=True)
    REGISTRY.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")


def _now() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")


def _version_entry(data: dict, name: str, version: str) -> dict:
    for v in data["models"].get(name, {}).get("versions", []):
        if v["version"] == version:
            return v
    raise KeyError(f"{name} {version} is not registered")


def load_artifact(name: str, version: str) -> tuple[dict, dict]:
    entry = _version_entry(_load(), name, version)
    folder = AI_ROOT / entry["artifact"]
    return json.loads((folder / "model.json").read_text()), json.loads((folder / "eval.json").read_text())


def production_artifact(name: str) -> dict | None:
    prod = _load()["models"].get(name, {}).get("production")
    return load_artifact(name, prod)[0] if prod else None


def register_run(run_dir: Path) -> dict:
    model_json = (run_dir / "artifact" / "model.json").read_bytes()
    artifact = json.loads(model_json)
    name, version = artifact["name"], artifact["version"]
    data = _load()
    model = data["models"].setdefault(name, {"production": None, "versions": []})
    for v in model["versions"]:
        if v["version"] == version and v["status"] not in ("candidate", "rejected"):
            raise ValueError(f"{name} {version} is {v['status']} and immutable — bump the version in the config")
    dest = ARTIFACTS / name / version
    dest.mkdir(parents=True, exist_ok=True)
    (dest / "model.json").write_bytes(model_json)
    shutil.copy(run_dir / "eval.json", dest / "eval.json")
    entry = {
        "version": version,
        "status": "candidate",
        "artifact": str(dest.relative_to(AI_ROOT)),
        "sha256": hashlib.sha256(model_json).hexdigest(),
        "run": artifact["provenance"]["trainRun"],
        "dataset": artifact["provenance"]["dataset"],
        "datasetSha256": artifact["provenance"]["datasetSha256"],
        "metrics": artifact["metrics"],
        "registeredAt": _now(),
    }
    model["versions"] = [v for v in model["versions"] if v["version"] != version] + [entry]
    _save(data)
    write_card(dest, artifact, json.loads((dest / "eval.json").read_text()), status="candidate")
    print(f"registered {name} {version} as candidate")
    return entry


def gate_checks(name: str, version: str, gate: dict) -> list[dict]:
    artifact, report = load_artifact(name, version)
    t, b = report["test"], report["baselineTest"]
    checks = [
        {
            "check": "beats rule baseline (test macro AUC gain)",
            "value": round(t["macroAuc"] - b["macroAuc"], 4),
            "required": f">= {gate['minMacroAucGainOverBaseline']}",
            "ok": t["macroAuc"] - b["macroAuc"] >= gate["minMacroAucGainOverBaseline"],
        },
        {
            "check": "quality ranking (test Spearman)",
            "value": round(t["quality"]["spearman"], 4),
            "required": f">= {gate['minQualitySpearman']}",
            "ok": t["quality"]["spearman"] >= gate["minQualitySpearman"],
        },
    ]
    data = _load()
    prod_version = data["models"].get(name, {}).get("production")
    if prod_version and prod_version != version:
        prod, _ = load_artifact(name, prod_version)
        if prod["input"]["featureVersion"] != artifact["input"]["featureVersion"]:
            checks.append({"check": f"no regression vs {prod_version}", "value": "feature versions differ", "required": "same", "ok": False})
        else:
            _, arrays = datasets.load_verified(artifact["provenance"]["dataset"])
            te = arrays["split"] == 2
            prod_auc = evaluate_model(ArtifactModel(prod), arrays["X"][te], arrays["y_defects"][te], arrays["y_quality"][te])["macroAuc"]
            drop = prod_auc - t["macroAuc"]
            checks.append({
                "check": f"no regression vs production {prod_version} (macro AUC drop)",
                "value": round(drop, 4),
                "required": f"<= {gate['maxMacroAucDropVsProduction']}",
                "ok": drop <= gate["maxMacroAucDropVsProduction"],
            })
    return checks


def promote(name: str, version: str, gate: dict) -> bool:
    checks = gate_checks(name, version, gate)
    for c in checks:
        print(f"  [{'ok' if c['ok'] else 'FAIL'}] {c['check']}: {c['value']} (required {c['required']})")
    data = _load()
    model = data["models"][name]
    entry = _version_entry(data, name, version)
    entry["gate"] = checks
    if not all(c["ok"] for c in checks):
        entry["status"] = "rejected"
        _save(data)
        print(f"{name} {version} rejected — production unchanged ({model['production']})")
        return False
    for v in model["versions"]:
        if v["status"] == "production":
            v["status"] = "archived"
    entry["status"] = "production"
    entry["promotedAt"] = _now()
    model["production"] = version
    _save(data)
    artifact, report = load_artifact(name, version)
    write_card(AI_ROOT / entry["artifact"], artifact, report, status="production")
    app_export.export(artifact)
    print(f"{name} {version} is production; exported to the app")
    return True


def rollback(name: str) -> str:
    data = _load()
    model = data["models"][name]
    current = model["production"]
    archived = [v for v in model["versions"] if v["status"] == "archived"]
    if not current or not archived:
        raise ValueError("nothing to roll back to")
    previous = max(archived, key=lambda v: v.get("promotedAt", ""))
    _version_entry(data, name, current)["status"] = "rolled_back"
    previous["status"] = "production"
    model["production"] = previous["version"]
    _save(data)
    app_export.export(load_artifact(name, previous["version"])[0])
    print(f"{name}: {current} → {previous['version']}")
    return previous["version"]


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    sub = ap.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("register")
    r.add_argument("--run", type=Path, required=True)
    p = sub.add_parser("promote")
    p.add_argument("--model", required=True)
    p.add_argument("--version", required=True)
    p.add_argument("--config", type=Path, default=CONFIGS_DIR / "scene_quality_v1.json")
    b = sub.add_parser("rollback")
    b.add_argument("--model", required=True)
    sub.add_parser("list")
    args = ap.parse_args()
    if args.cmd == "register":
        register_run(args.run if args.run.is_absolute() else AI_ROOT / args.run)
    elif args.cmd == "promote":
        cfg = args.config if args.config.is_absolute() else AI_ROOT / args.config
        ok = promote(args.model, args.version, json.loads(cfg.read_text())["gate"])
        raise SystemExit(0 if ok else 1)
    elif args.cmd == "rollback":
        rollback(args.model)
    else:
        for name, m in _load()["models"].items():
            print(f"{name}: production {m['production']}")
            for v in m["versions"]:
                print(f"  {v['version']:8s} {v['status']:11s} {v['metrics']['test']}")


if __name__ == "__main__":
    main()
