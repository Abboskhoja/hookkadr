"""Exports a production artifact to the Flutter app, with Dart parity goldens.

The goldens are small synthetic RGB frames with the features and model
outputs Python computes for them; ``test/scene_quality_test.dart`` checks that
Dart reproduces both, so the phone runs exactly the model that was evaluated.
"""

from __future__ import annotations

import base64
import hashlib
import json

import cv2
import numpy as np

from ..features.frame_quality import frame_features
from ..models.scene_quality import ArtifactModel
from ..paths import APP_MODELS_DIR, APP_TEST_FIXTURES_DIR


def golden_frames() -> dict[str, np.ndarray]:
    h, w = 48, 64
    yy, xx = np.mgrid[0:h, 0:w]
    pattern = np.stack([(xx * 4) % 256, (yy * 5) % 256, ((xx // 8 + yy // 8) % 2) * 255], -1).astype(np.uint8)
    rng = np.random.default_rng(7)
    return {
        "pattern": pattern,
        "random": rng.integers(0, 256, (h, w, 3), dtype=np.uint8),
        "dark": (pattern.astype(np.float64) * 0.15).astype(np.uint8),
        "bright": np.clip(pattern.astype(np.int64) + 140, 0, 255).astype(np.uint8),
        "flat": np.full((h, w, 3), 128, np.uint8),
        "blurred": cv2.GaussianBlur(pattern, (0, 0), 2.0),
        "odd_size": rng.integers(0, 256, (13, 17, 3), dtype=np.uint8),
    }


def export(artifact: dict) -> None:
    text = json.dumps(artifact, separators=(",", ":"))
    APP_MODELS_DIR.mkdir(parents=True, exist_ok=True)
    (APP_MODELS_DIR / f"{artifact['name']}.json").write_text(text)

    model = ArtifactModel(artifact)
    frames = []
    for name, rgb in golden_frames().items():
        f = frame_features(rgb)
        q, d = model.predict(f[None, :])
        frames.append(
            {
                "name": name,
                "width": int(rgb.shape[1]),
                "height": int(rgb.shape[0]),
                "rgbBase64": base64.b64encode(np.ascontiguousarray(rgb).tobytes()).decode(),
                "features": [float(v) for v in f],
                "quality": float(q[0]),
                "defects": {k: float(d[0, j]) for j, k in enumerate(model.defects)},
            }
        )
    golden = {
        "model": artifact["name"],
        "version": artifact["version"],
        "artifactSha256": hashlib.sha256(text.encode()).hexdigest(),
        "frames": frames,
    }
    APP_TEST_FIXTURES_DIR.mkdir(parents=True, exist_ok=True)
    (APP_TEST_FIXTURES_DIR / f"{artifact['name']}_golden.json").write_text(json.dumps(golden, indent=1))
