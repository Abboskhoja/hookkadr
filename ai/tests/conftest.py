from __future__ import annotations

import numpy as np
import pytest
import torch

from hookkadr_ai.datasets.degrade import DEFECTS
from hookkadr_ai.features.frame_quality import FEATURE_NAMES, FEATURE_VERSION
from hookkadr_ai.media.ffmpeg import ANALYSIS_FILTER, ANALYSIS_LONG_SIDE
from hookkadr_ai.models.scene_quality import SceneQualityNet, export_artifact


def make_artifact(seed: int = 0, version: str = "0.0.1", metrics: dict | None = None) -> dict:
    torch.manual_seed(seed)
    net = SceneQualityNet(len(FEATURE_NAMES), [8], len(DEFECTS))
    rng = np.random.default_rng(seed)
    return export_artifact(
        net,
        rng.normal(size=len(FEATURE_NAMES)),
        rng.uniform(0.5, 2.0, size=len(FEATURE_NAMES)),
        meta={
            "name": "scene_quality",
            "version": version,
            "task": "frame_quality",
            "input": {
                "featureVersion": FEATURE_VERSION,
                "features": list(FEATURE_NAMES),
                "analysisFilter": ANALYSIS_FILTER,
                "analysisLongSide": ANALYSIS_LONG_SIDE,
            },
            "defects": list(DEFECTS),
            "thresholds": {d: 0.5 for d in DEFECTS},
            "provenance": {
                "baseModel": None,
                "architecture": "MLP test",
                "framework": "torch",
                "dataset": "test_ds",
                "datasetSha256": "0" * 64,
                "trainRun": f"scene_quality/test-{version}",
                "git": "test",
                "bestEpoch": 0,
                "labelling": "test",
            },
            "metrics": metrics or {},
        },
    )


@pytest.fixture
def artifact() -> dict:
    return make_artifact()


def pattern_rgb(h: int = 72, w: int = 128) -> np.ndarray:
    yy, xx = np.mgrid[0:h, 0:w]
    return np.stack([(xx * 7) % 256, (yy * 3) % 256, ((xx // 6 + yy // 6) % 2) * 255], -1).astype(np.uint8)
