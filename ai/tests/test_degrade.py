import numpy as np
import pytest

from conftest import pattern_rgb
from hookkadr_ai.datasets.degrade import INCOMPATIBLE, Op, apply_op, degrade, labels_of, sample_ops


def base() -> np.ndarray:
    return pattern_rgb(90, 160).astype(np.float32) / 255.0


def test_labels_and_quality_target():
    y, q = labels_of([Op("blur_gauss", 0.5), Op("noise", 0.2)])
    assert y.tolist() == [1, 0, 0, 0, 0]  # noise below the 0.3 positive severity
    assert q == pytest.approx((1 - 0.45) * (1 - 0.18))
    assert labels_of([])[1] == 1.0


def test_ops_move_pictures_the_expected_way():
    img = base()
    rng = np.random.default_rng(0)
    hf = lambda x: np.abs(np.diff(x.mean(-1), axis=1)).mean()  # noqa: E731
    assert hf(apply_op(img, Op("blur_gauss", 0.6), rng)) < hf(img)
    assert hf(apply_op(img, Op("blur_motion", 0.6), rng)) < hf(img)
    assert apply_op(img, Op("dark", 0.6), rng).mean() < img.mean()
    assert apply_op(img, Op("overexposed", 0.6), rng).mean() > img.mean()
    assert apply_op(img, Op("low_contrast", 0.6), rng).std() < img.std()
    noisy = apply_op(img, Op("noise", 0.6), rng)
    assert np.abs(noisy - img).mean() > 0.03


def test_degrade_is_reproducible():
    img = base()
    ops1 = sample_ops(np.random.default_rng([1, 2, 3]))
    ops2 = sample_ops(np.random.default_rng([1, 2, 3]))
    assert [(o.kind, o.severity) for o in ops1] == [(o.kind, o.severity) for o in ops2]
    a = degrade(img, ops1, np.random.default_rng(5))
    b = degrade(img, ops2, np.random.default_rng(5))
    assert np.array_equal(a, b)


def test_sampled_ops_are_compatible():
    rng = np.random.default_rng(9)
    for _ in range(2000):
        kinds = {o.kind for o in sample_ops(rng)}
        assert 1 <= len(kinds) <= 2
        assert not any(pair <= kinds for pair in INCOMPATIBLE)
