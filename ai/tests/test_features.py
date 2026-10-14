import cv2
import numpy as np
import pytest

from conftest import pattern_rgb
from hookkadr_ai.features.frame_quality import FEATURE_NAMES, _box_mean, frame_features


def feat(rgb: np.ndarray) -> dict[str, float]:
    return dict(zip(FEATURE_NAMES, frame_features(rgb)))


def test_shape_and_determinism():
    rgb = pattern_rgb()
    a, b = frame_features(rgb), frame_features(rgb.copy())
    assert a.shape == (len(FEATURE_NAMES),)
    assert np.array_equal(a, b)


def test_flat_frame_has_no_detail():
    f = feat(np.full((40, 60, 3), 128, np.uint8))
    assert f["lap_var_log"] == 0 and f["tenengrad_log"] == 0 and f["detail_ratio"] == 0
    assert f["entropy"] == 0 and f["y_std"] == 0 and f["noise_log"] == 0
    assert f["p05"] == f["p50"] == f["p95"] == pytest.approx(128 / 255)


def test_blur_lowers_sharpness_and_detail():
    rgb = pattern_rgb()
    sharp, soft = feat(rgb), feat(cv2.GaussianBlur(rgb, (0, 0), 2.0))
    assert soft["lap_var_log"] < sharp["lap_var_log"]
    assert soft["detail_ratio"] < sharp["detail_ratio"]
    assert soft["edge_density"] < sharp["edge_density"]


def test_exposure_features_follow_brightness():
    rgb = pattern_rgb()
    dark = (rgb.astype(float) * 0.1).astype(np.uint8)
    bright = np.clip(rgb.astype(int) + 150, 0, 255).astype(np.uint8)
    f, fd, fb = feat(rgb), feat(dark), feat(bright)
    assert fd["y_mean"] < f["y_mean"] < fb["y_mean"]
    assert fd["dark_frac"] > f["dark_frac"]
    assert fb["bright_frac"] > f["bright_frac"]


def test_noise_raises_noise_estimate():
    rgb = cv2.GaussianBlur(pattern_rgb(), (0, 0), 1.0)
    noisy = np.clip(rgb + np.random.default_rng(1).normal(0, 20, rgb.shape), 0, 255).astype(np.uint8)
    assert feat(noisy)["noise_log"] > feat(rgb)["noise_log"] + 0.5


def test_box_mean_matches_naive_window_mean():
    y = np.random.default_rng(2).random((11, 14)) * 255
    box = _box_mean(y, 1)
    naive = np.array([[y[i - 1 : i + 2, j - 1 : j + 2].mean() for j in range(1, 13)] for i in range(1, 10)])
    np.testing.assert_allclose(box, naive, rtol=1e-12)


def test_rejects_bad_input():
    with pytest.raises(ValueError):
        frame_features(np.zeros((8, 8, 3), np.uint8))
    with pytest.raises(ValueError):
        frame_features(np.zeros((20, 20, 3), np.float32))
