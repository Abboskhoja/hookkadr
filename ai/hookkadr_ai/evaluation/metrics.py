"""Evaluation metrics in plain numpy (no scikit-learn dependency)."""

from __future__ import annotations

import numpy as np


def rankdata(x: np.ndarray) -> np.ndarray:
    """1-based ranks with ties averaged."""
    x = np.asarray(x, np.float64)
    order = np.argsort(x, kind="mergesort")
    ranks = np.empty(len(x), np.float64)
    sx = x[order]
    i = 0
    while i < len(x):
        j = i
        while j + 1 < len(x) and sx[j + 1] == sx[i]:
            j += 1
        ranks[order[i : j + 1]] = (i + j) / 2.0 + 1.0
        i = j + 1
    return ranks


def roc_auc(y: np.ndarray, score: np.ndarray) -> float:
    """Mann-Whitney AUC; NaN when only one class is present."""
    y = np.asarray(y).astype(bool)
    n_pos, n_neg = int(y.sum()), int((~y).sum())
    if n_pos == 0 or n_neg == 0:
        return float("nan")
    r = rankdata(score)
    return float((r[y].sum() - n_pos * (n_pos + 1) / 2.0) / (n_pos * n_neg))


def average_precision(y: np.ndarray, score: np.ndarray) -> float:
    y = np.asarray(y).astype(bool)
    if y.sum() == 0:
        return float("nan")
    order = np.argsort(-np.asarray(score, np.float64), kind="mergesort")
    s, yy = np.asarray(score)[order], y[order]
    tp = np.cumsum(yy)
    fp = np.cumsum(~yy)
    # Evaluate only at the last index of each distinct score (threshold).
    last = np.r_[np.nonzero(np.diff(s))[0], len(s) - 1]
    precision = tp[last] / (tp[last] + fp[last])
    recall = tp[last] / y.sum()
    recall_prev = np.r_[0.0, recall[:-1]]
    return float(np.sum((recall - recall_prev) * precision))


def prf_at(y: np.ndarray, score: np.ndarray, threshold: float) -> dict[str, float]:
    y = np.asarray(y).astype(bool)
    pred = np.asarray(score) >= threshold
    tp = int((pred & y).sum())
    fp = int((pred & ~y).sum())
    fn = int((~pred & y).sum())
    p = tp / (tp + fp) if tp + fp else 0.0
    r = tp / (tp + fn) if tp + fn else 0.0
    f1 = 2 * p * r / (p + r) if p + r else 0.0
    return {"precision": p, "recall": r, "f1": f1, "accuracy": float((pred == y).mean())}


def best_f1_threshold(y: np.ndarray, score: np.ndarray) -> float:
    """Threshold (searched over score quantiles) that maximises F1."""
    candidates = np.unique(np.quantile(np.asarray(score, np.float64), np.linspace(0.01, 0.99, 197)))
    best_t, best_f = float(candidates[0]), -1.0
    for t in candidates:
        f = prf_at(y, score, float(t))["f1"]
        if f > best_f:
            best_t, best_f = float(t), f
    return best_t


def spearman(a: np.ndarray, b: np.ndarray) -> float:
    return pearson(rankdata(a), rankdata(b))


def pearson(a: np.ndarray, b: np.ndarray) -> float:
    a = np.asarray(a, np.float64) - np.mean(a)
    b = np.asarray(b, np.float64) - np.mean(b)
    d = np.sqrt((a * a).sum() * (b * b).sum())
    return float((a * b).sum() / d) if d > 0 else float("nan")


def mae(a: np.ndarray, b: np.ndarray) -> float:
    return float(np.mean(np.abs(np.asarray(a, np.float64) - np.asarray(b, np.float64))))
