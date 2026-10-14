import numpy as np
import pytest

from hookkadr_ai.evaluation.metrics import average_precision, best_f1_threshold, prf_at, rankdata, roc_auc, spearman


def test_rankdata_averages_ties():
    assert rankdata(np.array([3, 1, 3, 2])).tolist() == [3.5, 1.0, 3.5, 2.0]


def test_roc_auc():
    y = np.array([0, 0, 1, 1])
    assert roc_auc(y, np.array([0.1, 0.2, 0.8, 0.9])) == 1.0
    assert roc_auc(y, np.array([0.9, 0.8, 0.2, 0.1])) == 0.0
    assert roc_auc(y, np.array([0.5, 0.5, 0.5, 0.5])) == 0.5
    assert roc_auc(y, np.array([0.1, 0.4, 0.35, 0.8])) == 0.75
    assert np.isnan(roc_auc(np.array([1, 1]), np.array([0.1, 0.2])))


def test_average_precision_known_value():
    # Ranked: 1 (pos), 2 (neg), 3 (pos) -> AP = (1/2)*1 + (1/2)*(2/3)
    y = np.array([1, 0, 1])
    s = np.array([0.9, 0.8, 0.7])
    assert average_precision(y, s) == pytest.approx(0.5 + 1 / 3)


def test_prf_and_best_threshold():
    y = np.array([0, 0, 1, 1, 1])
    s = np.array([0.1, 0.2, 0.6, 0.7, 0.9])
    assert prf_at(y, s, 0.5)["f1"] == 1.0
    t = best_f1_threshold(y, s)
    assert 0.2 < t <= 0.6


def test_spearman():
    a = np.array([1, 2, 3, 4])
    assert spearman(a, a * 10) == pytest.approx(1.0)
    assert spearman(a, -a) == pytest.approx(-1.0)
