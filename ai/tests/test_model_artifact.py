import json

import numpy as np
import pytest
import torch

from hookkadr_ai.features.frame_quality import FEATURE_NAMES
from hookkadr_ai.models.scene_quality import ArtifactModel, SceneQualityNet, export_artifact

from conftest import make_artifact


def test_artifact_reproduces_torch_network():
    torch.manual_seed(3)
    net = SceneQualityNet(len(FEATURE_NAMES), [16, 8], 5)
    mean = np.linspace(-1, 1, len(FEATURE_NAMES))
    std = np.linspace(0.5, 2, len(FEATURE_NAMES))
    art = make_artifact()
    art = export_artifact(net, mean, std, meta={**{k: art[k] for k in ("name", "version", "task", "input", "thresholds", "provenance")}, "defects": art["outputs"]["defects"]})
    art = json.loads(json.dumps(art))  # what Dart and the service load
    X = np.random.default_rng(0).normal(size=(64, len(FEATURE_NAMES)))
    with torch.no_grad():
        expected = torch.sigmoid(net(torch.tensor((X - mean) / std, dtype=torch.float32))).numpy()
    q, d = ArtifactModel(art).predict(X)
    assert np.max(np.abs(np.column_stack([q, d]) - expected)) < 1e-5


def test_flags_use_thresholds(artifact):
    model = ArtifactModel(artifact)
    probs = np.array([[0.6, 0.4, 0.5, 0.1, 0.9]])
    assert model.flags(probs) == [["blurry", "overexposed", "low_contrast"]]


def test_rejects_unknown_schema(artifact):
    with pytest.raises(ValueError):
        ArtifactModel({**artifact, "schema": "other/9"})
