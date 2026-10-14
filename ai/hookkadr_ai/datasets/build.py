"""Builds the Scene Quality dataset from licensed source photos.

Each source photo gives up to two 720p "capture" crops (16:9 and 9:16, never
upscaled). Every crop yields one clean frame and N defective ones; every frame
then goes through a JPEG round trip (codec nuisance) and the same FFmpeg
reduction the app uses, and its features are computed.

Splits are by source photo, so no photo leaks between train, val and test.

Usage::

    uv run python -m hookkadr_ai.datasets.build --config configs/scene_quality_v1.json
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import platform
import subprocess
import time
from multiprocessing import Pool
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageOps

from ..features.frame_quality import FEATURE_NAMES, FEATURE_VERSION, frame_features
from ..media.ffmpeg import ANALYSIS_FILTER, analysis_frames_from_rgb
from ..paths import AI_ROOT, DATASETS_DIR, REGISTRY_DIR, SOURCES_DIR
from . import registry
from .degrade import DEFECTS, POSITIVE_SEVERITY, Op, degrade, jpeg_roundtrip, labels_of, sample_ops
from .sources import load_manifest

LANDSCAPE = (1280, 720)
PORTRAIT = (720, 1280)
SPLITS = ("train", "val", "test")


def split_of(source_id: str, fractions: dict[str, float]) -> int:
    bucket = int(hashlib.sha256(source_id.encode()).hexdigest()[:8], 16) % 1000 / 1000
    edge = 0.0
    for i, name in enumerate(SPLITS):
        edge += fractions[name]
        if bucket < edge:
            return i
    return len(SPLITS) - 1


def capture_crops(rgb: np.ndarray) -> list[tuple[str, np.ndarray]]:
    """Center crops at video aspect ratios, downscaled with INTER_AREA (never upscaled)."""
    h, w, _ = rgb.shape
    out: list[tuple[str, np.ndarray]] = []
    for name, (tw, th) in (("landscape", LANDSCAPE), ("portrait", PORTRAIT)):
        if w * th >= h * tw:  # source wider than target: full height
            ch, cw = h, int(round(h * tw / th))
        else:
            cw, ch = w, int(round(w * th / tw))
        if cw < tw or ch < th:
            continue
        x0, y0 = (w - cw) // 2, (h - ch) // 2
        crop = rgb[y0 : y0 + ch, x0 : x0 + cw]
        out.append((name, cv2.resize(crop, (tw, th), interpolation=cv2.INTER_AREA)))
    return out


def _build_source(job: tuple[int, str, str, int, dict]) -> tuple[int, list[np.ndarray], list[dict]]:
    index, source_id, path, seed, cfg = job
    with Image.open(path) as im:
        rgb = np.asarray(ImageOps.exif_transpose(im).convert("RGB"))
    feats: list[np.ndarray] = []
    records: list[dict] = []
    for ci, (orientation, crop) in enumerate(capture_crops(rgb)):
        base = crop.astype(np.float32) / 255.0
        frames: list[np.ndarray] = []
        for v in range(1 + cfg["defectiveVariants"]):
            rng = np.random.default_rng([seed, index, ci, v])
            ops: list[Op] = [] if v == 0 else sample_ops(rng)
            img = degrade(base, ops, rng)
            u8 = np.clip(img * 255.0 + 0.5, 0, 255).astype(np.uint8)
            jq = int(rng.integers(cfg["jpegQuality"][0], cfg["jpegQuality"][1] + 1))
            frames.append(jpeg_roundtrip(u8, jq))
            y, q = labels_of(ops)
            records.append(
                {
                    "source": source_id,
                    "orientation": orientation,
                    "variant": v,
                    "ops": [{"kind": o.kind, "severity": round(o.severity, 4), **o.params} for o in ops],
                    "labels": {d: int(y[i]) for i, d in enumerate(DEFECTS)},
                    "quality": round(q, 5),
                    "jpegQuality": jq,
                }
            )
        for a in analysis_frames_from_rgb(frames):
            feats.append(frame_features(a))
    return index, feats, records


def _git_commit() -> str:
    try:
        return subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=AI_ROOT, capture_output=True, text=True).stdout.strip()
    except OSError:
        return "unknown"


def build(config_path: Path, workers: int) -> dict:
    cfg_all = json.loads(config_path.read_text())
    cfg = cfg_all["dataset"]
    src_dir = AI_ROOT / cfg["sourcesDir"]
    sources = [s for s in load_manifest(src_dir) if s.topic not in set(cfg.get("excludeTopics", []))]
    sources.sort(key=lambda s: s.id)
    jobs = [(i, s.id, str(src_dir / s.file), cfg["seed"], cfg) for i, s in enumerate(sources)]

    t0 = time.time()
    with Pool(workers) as pool:
        results = sorted(pool.imap_unordered(_build_source, jobs, chunksize=2), key=lambda r: r[0])

    feats: list[np.ndarray] = []
    records: list[dict] = []
    source_idx: list[int] = []
    for index, f, r in results:
        feats.extend(f)
        records.extend(r)
        source_idx.extend([index] * len(f))
    X = np.stack(feats)
    y_def = np.array([[r["labels"][d] for d in DEFECTS] for r in records], np.float32)
    y_q = np.array([r["quality"] for r in records], np.float32)
    split = np.array([split_of(sources[i].id, cfg["split"]) for i in source_idx], np.int8)

    out_dir = DATASETS_DIR / cfg["id"]
    out_dir.mkdir(parents=True, exist_ok=True)
    samples = out_dir / "samples.npz"
    arrays = {"X": X, "y_defects": y_def, "y_quality": y_q, "source": np.array(source_idx, np.int32), "split": split}
    np.savez_compressed(samples, **arrays)
    with (out_dir / "samples.jsonl").open("w") as f:
        for r in records:
            f.write(json.dumps(r) + "\n")

    counts = {name: int((split == i).sum()) for i, name in enumerate(SPLITS)}
    positives = {
        name: {d: int(y_def[split == i, j].sum()) for j, d in enumerate(DEFECTS)} for i, name in enumerate(SPLITS)
    }
    licences: dict[str, int] = {}
    for s in sources:
        licences[s.license] = licences.get(s.license, 0) + 1
    entry = {
        "id": cfg["id"],
        "task": "frame_quality",
        "createdAt": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "samples": str(samples.relative_to(AI_ROOT)),
        "sha256": registry.content_hash(arrays),
        "rebuild": f"uv run python -m hookkadr_ai.datasets.build --config {config_path.relative_to(AI_ROOT)}",
        "featureVersion": FEATURE_VERSION,
        "features": list(FEATURE_NAMES),
        "defects": list(DEFECTS),
        "positiveSeverity": POSITIVE_SEVERITY,
        "analysisFilter": ANALYSIS_FILTER,
        "sources": {
            "manifest": str((src_dir / "manifest.json").relative_to(AI_ROOT)),
            "manifestSha256": registry.sha256_file(src_dir / "manifest.json"),
            "count": len(sources),
            "licences": licences,
            "excludedTopics": cfg.get("excludeTopics", []),
        },
        "counts": counts,
        "positives": positives,
        "config": cfg,
        "builder": {"git": _git_commit(), "python": platform.python_version(), "numpy": np.__version__, "opencv": cv2.__version__},
        "labelling": "self-supervised: controlled defects with known severity on CC0/PD photos; not human-rated",
    }
    # Preserve source identities, licence declarations and download hashes
    # beside the committed registry; the large local data directory is ignored.
    manifest_snapshot = REGISTRY_DIR / "source_manifests" / f"{cfg['id']}.json"
    manifest_snapshot.parent.mkdir(parents=True, exist_ok=True)
    manifest_snapshot.write_bytes((src_dir / "manifest.json").read_bytes())
    entry["sources"]["snapshot"] = str(manifest_snapshot.relative_to(AI_ROOT))
    registry.register(entry)
    (out_dir / "dataset.json").write_text(json.dumps(entry, indent=2))
    print(f"{len(records)} samples from {len(sources)} photos in {time.time() - t0:.0f} s: {counts}")
    return entry


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--config", type=Path, required=True)
    ap.add_argument("--workers", type=int, default=max(1, (os.cpu_count() or 2) - 1))
    args = ap.parse_args()
    build(args.config if args.config.is_absolute() else AI_ROOT / args.config, args.workers)


if __name__ == "__main__":
    main()
