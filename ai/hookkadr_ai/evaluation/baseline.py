"""Rule baseline: the best single-feature "if x < t" rule per defect.

This is what a hand-written detector looks like (e.g. "blurry if Laplacian
variance is low"), with the feature, direction and threshold chosen on the
training split. The learned model must beat it to be promoted.
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np

from ..features.frame_quality import FEATURE_NAMES
from .metrics import best_f1_threshold, roc_auc

CANDIDATES: dict[str, tuple[str, ...]] = {
    "blurry": ("lap_var_log", "tenengrad_log", "detail_ratio", "edge_density"),
    "dark": ("y_mean", "p50", "p95", "dark_frac"),
    "overexposed": ("y_mean", "p50", "p05", "bright_frac"),
    "noisy": ("noise_log", "detail_ratio"),
    "low_contrast": ("y_std", "entropy", "p05", "p95"),
}


@dataclass(frozen=True)
class Rule:
    defect: str
    feature: str
    direction: float  # +1: high value means defect; -1: low value means defect
    threshold: float  # on direction * value

    def score(self, X: np.ndarray) -> np.ndarray:
        return self.direction * X[:, FEATURE_NAMES.index(self.feature)]

    def describe(self) -> str:
        op = ">=" if self.direction > 0 else "<="
        return f"{self.defect} if {self.feature} {op} {self.direction * self.threshold:.4f}"


def fit_rules(X: np.ndarray, Y: np.ndarray, defects: list[str]) -> list[Rule]:
    rules: list[Rule] = []
    for j, defect in enumerate(defects):
        best: tuple[float, str, float] | None = None
        for feature in CANDIDATES[defect]:
            x = X[:, FEATURE_NAMES.index(feature)]
            for direction in (1.0, -1.0):
                auc = roc_auc(Y[:, j], direction * x)
                if best is None or auc > best[0]:
                    best = (auc, feature, direction)
        assert best is not None
        _, feature, direction = best
        s = direction * X[:, FEATURE_NAMES.index(feature)]
        rules.append(Rule(defect, feature, direction, best_f1_threshold(Y[:, j], s)))
    return rules


def fit_quality_rule(X: np.ndarray, q: np.ndarray) -> tuple[str, float]:
    """Single feature whose ranking best matches the quality target (train split)."""
    from .metrics import spearman

    best = max(
        ((name, d) for name in FEATURE_NAMES for d in (1.0, -1.0)),
        key=lambda nd: spearman(nd[1] * X[:, FEATURE_NAMES.index(nd[0])], q),
    )
    return best
