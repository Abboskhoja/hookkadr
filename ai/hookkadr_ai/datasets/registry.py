"""Dataset registry: every built dataset version with its content hash.

``registry/datasets.json`` is committed; the data itself (``data/``) is not.
A training run records the dataset id and hash, and refuses to train when the
files on disk no longer match the registered hash.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np

from ..paths import AI_ROOT, REGISTRY_DIR

REGISTRY = REGISTRY_DIR / "datasets.json"


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def content_hash(arrays: dict[str, np.ndarray]) -> str:
    """Hash of array names, dtypes, shapes and bytes (zip timestamps do not count)."""
    h = hashlib.sha256()
    for name in sorted(arrays):
        a = np.ascontiguousarray(arrays[name])
        h.update(f"{name}|{a.dtype.str}|{a.shape}|".encode())
        h.update(a.tobytes())
    return h.hexdigest()


def _load() -> dict:
    if REGISTRY.exists():
        return json.loads(REGISTRY.read_text())
    return {"datasets": []}


def register(entry: dict) -> None:
    data = _load()
    data["datasets"] = [d for d in data["datasets"] if d["id"] != entry["id"]] + [entry]
    REGISTRY.parent.mkdir(parents=True, exist_ok=True)
    REGISTRY.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")


def get(dataset_id: str) -> dict:
    for d in _load()["datasets"]:
        if d["id"] == dataset_id:
            return d
    raise KeyError(f"dataset {dataset_id} is not registered")


def load_verified(dataset_id: str) -> tuple[dict, dict[str, np.ndarray]]:
    """The registry entry and arrays of a dataset, after checking the content hash."""
    entry = get(dataset_id)
    path = AI_ROOT / entry["samples"]
    if not path.exists():
        raise FileNotFoundError(f"{path} missing — rebuild with: {entry['rebuild']}")
    with np.load(path) as z:
        arrays = {k: z[k] for k in z.files}
    digest = content_hash(arrays)
    if digest != entry["sha256"]:
        raise ValueError(f"{dataset_id}: content hash mismatch ({digest[:12]} != {entry['sha256'][:12]})")
    return entry, arrays
