"""Evaluation of a model artifact (and the rule baseline) on a dataset split."""

from __future__ import annotations

import numpy as np

from ..features.frame_quality import FEATURE_NAMES
from ..models.scene_quality import ArtifactModel
from .baseline import Rule
from .metrics import average_precision, mae, pearson, prf_at, roc_auc, spearman


def _nanmean(xs: list[float]) -> float:
    vals = [x for x in xs if x == x]
    return float(np.mean(vals)) if vals else float("nan")


def evaluate_model(model: ArtifactModel, X: np.ndarray, Y: np.ndarray, q: np.ndarray) -> dict:
    quality, probs = model.predict(X)
    per: dict[str, dict] = {}
    for j, d in enumerate(model.defects):
        per[d] = {
            "auc": roc_auc(Y[:, j], probs[:, j]),
            "ap": average_precision(Y[:, j], probs[:, j]),
            "threshold": model.thresholds[d],
            **prf_at(Y[:, j], probs[:, j], model.thresholds[d]),
            "positives": int(Y[:, j].sum()),
        }
    return {
        "n": int(len(X)),
        "defects": per,
        "macroAuc": _nanmean([v["auc"] for v in per.values()]),
        "macroF1": _nanmean([v["f1"] for v in per.values()]),
        "quality": {"mae": mae(quality, q), "spearman": spearman(quality, q), "pearson": pearson(quality, q)},
    }


def evaluate_rules(
    rules: list[Rule], quality_rule: tuple[str, float], X: np.ndarray, Y: np.ndarray, q: np.ndarray
) -> dict:
    per: dict[str, dict] = {}
    for j, rule in enumerate(rules):
        s = rule.score(X)
        per[rule.defect] = {
            "rule": rule.describe(),
            "auc": roc_auc(Y[:, j], s),
            "ap": average_precision(Y[:, j], s),
            **prf_at(Y[:, j], s, rule.threshold),
        }
    feature, direction = quality_rule
    qs = direction * X[:, FEATURE_NAMES.index(feature)]
    return {
        "n": int(len(X)),
        "defects": per,
        "macroAuc": _nanmean([v["auc"] for v in per.values()]),
        "macroF1": _nanmean([v["f1"] for v in per.values()]),
        "quality": {"rule": f"{'+' if direction > 0 else '-'}{feature}", "spearman": spearman(qs, q)},
    }
