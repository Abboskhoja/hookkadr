"""HOOKKADR Vision · Scene Quality: a small MLP over frame quality features.

Outputs one quality score and five defect probabilities per frame. Trained
with PyTorch; deployed as a JSON artifact that numpy (inference service) and
Dart (phone) evaluate identically, so there is one source of truth.
"""

from __future__ import annotations

import numpy as np
import torch
from torch import nn

ARTIFACT_SCHEMA = "hookkadr.model/1"


class SceneQualityNet(nn.Module):
    def __init__(self, n_in: int, hidden: list[int], n_defects: int):
        super().__init__()
        layers: list[nn.Module] = []
        prev = n_in
        for width in hidden:
            layers += [nn.Linear(prev, width), nn.ReLU()]
            prev = width
        layers.append(nn.Linear(prev, 1 + n_defects))  # [quality, *defects] logits
        self.net = nn.Sequential(*layers)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.net(x)


def export_artifact(
    net: SceneQualityNet,
    mean: np.ndarray,
    std: np.ndarray,
    *,
    meta: dict,
) -> dict:
    """JSON-serialisable artifact. ``meta`` carries name, version, input spec,
    defects, thresholds, provenance and metrics."""
    linears = [m for m in net.net if isinstance(m, nn.Linear)]
    layers = [
        {
            "weights": lin.weight.detach().to(torch.float64).tolist(),
            "bias": lin.bias.detach().to(torch.float64).tolist(),
            "activation": "relu" if i < len(linears) - 1 else "linear",
        }
        for i, lin in enumerate(linears)
    ]
    return {
        "schema": ARTIFACT_SCHEMA,
        **{k: meta[k] for k in ("name", "version", "task")},
        "input": meta["input"],
        "normalization": {"mean": [float(v) for v in mean], "std": [float(v) for v in std]},
        "layers": layers,
        "outputs": {"quality": 0, "defects": meta["defects"], "activation": "sigmoid"},
        "thresholds": meta["thresholds"],
        "provenance": meta["provenance"],
        "metrics": meta.get("metrics", {}),
    }


def _sigmoid(z: np.ndarray) -> np.ndarray:
    return 1.0 / (1.0 + np.exp(-z))


class ArtifactModel:
    """Evaluates an exported artifact with numpy, the same way Dart does."""

    def __init__(self, artifact: dict):
        if artifact.get("schema") != ARTIFACT_SCHEMA:
            raise ValueError(f"unsupported artifact schema {artifact.get('schema')}")
        self.artifact = artifact
        self.name = artifact["name"]
        self.version = artifact["version"]
        self.defects: list[str] = list(artifact["outputs"]["defects"])
        self.thresholds: dict[str, float] = artifact["thresholds"]
        self.mean = np.asarray(artifact["normalization"]["mean"], np.float64)
        self.std = np.asarray(artifact["normalization"]["std"], np.float64)
        self.layers = [
            (np.asarray(l["weights"], np.float64), np.asarray(l["bias"], np.float64), l["activation"])
            for l in artifact["layers"]
        ]

    def logits(self, X: np.ndarray) -> np.ndarray:
        z = (np.asarray(X, np.float64) - self.mean) / self.std
        for w, b, act in self.layers:
            z = z @ w.T + b
            if act == "relu":
                z = np.maximum(z, 0.0)
        return z

    def predict(self, X: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
        """(quality[N], defect probabilities[N, D])."""
        p = _sigmoid(self.logits(X))
        return p[:, 0], p[:, 1:]

    def flags(self, defect_probs: np.ndarray) -> list[list[str]]:
        return [[d for j, d in enumerate(self.defects) if row[j] >= self.thresholds[d]] for row in defect_probs]
