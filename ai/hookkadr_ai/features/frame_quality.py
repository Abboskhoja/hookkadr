"""Frame quality features, version 1.

The same arithmetic is implemented in Dart
(``lib/features/vision/frame_quality_features.dart``) so the model trained here
runs on the phone. Parity rules, checked by golden tests on both sides:

* luma is ``(299 R + 587 G + 114 B) / 1000`` in float64; histogram codes use the
  exact integer ``(299 R + 587 G + 114 B + 500) // 1000``;
* every per-pixel expression is evaluated in the order written here;
* reductions are plain means / population variances (two-pass).

Changing any formula means bumping ``FEATURE_VERSION`` and retraining.
"""

from __future__ import annotations

import math

import numpy as np

FEATURE_VERSION = 1

FEATURE_NAMES: tuple[str, ...] = (
    "lap_var_log",  # log1p(variance of the 4-neighbour Laplacian): sharpness
    "tenengrad_log",  # log1p(mean squared Sobel gradient): edge energy
    "detail_ratio",  # fine detail / coarse detail: blur vs. noise
    "edge_density",  # share of pixels with Sobel magnitude > 100
    "y_mean",  # mean luma / 255
    "y_std",  # luma standard deviation / 255: global contrast
    "p05",  # 5th percentile luma code / 255
    "p50",  # median luma code / 255
    "p95",  # 95th percentile luma code / 255
    "dark_frac",  # share of luma codes < 20 (crushed shadows)
    "bright_frac",  # share of luma codes > 235 (clipped highlights)
    "noise_log",  # log1p(Immerkaer noise sigma)
    "colorfulness",  # Hasler-Suesstrunk colourfulness / 100
    "sat_mean",  # mean HSV saturation
    "entropy",  # luma histogram entropy / 8 bits
)

EDGE_THRESHOLD_SQ = 10000.0
DARK_CODE = 20
BRIGHT_CODE = 235
DETAIL_EPS = 0.5
MIN_SIDE = 12


def _percentile(hist: np.ndarray, n: int, p: float) -> int:
    target = p * n
    cum = 0
    for v in range(256):
        cum += int(hist[v])
        if cum >= target:
            return v
    return 255


def _box_mean(y: np.ndarray, k: int) -> np.ndarray:
    """Mean over a (2k+1)^2 window; returns the valid region (h-2k, w-2k).

    Summed term by term (columns first, then rows) so Dart can reproduce the
    exact floating-point results.
    """
    h, w = y.shape
    size = 2 * k + 1
    hs = y[:, 0 : w - 2 * k].copy()
    for dx in range(1, size):
        hs = hs + y[:, dx : w - 2 * k + dx]
    vs = hs[0 : h - 2 * k, :].copy()
    for dy in range(1, size):
        vs = vs + hs[dy : h - 2 * k + dy, :]
    return vs / float(size * size)


def frame_features(rgb: np.ndarray) -> np.ndarray:
    """Features of one RGB frame (``uint8``, shape ``(h, w, 3)``)."""
    if rgb.dtype != np.uint8 or rgb.ndim != 3 or rgb.shape[2] != 3:
        raise ValueError("expected an RGB uint8 array of shape (h, w, 3)")
    h, w, _ = rgb.shape
    if h < MIN_SIDE or w < MIN_SIDE:
        raise ValueError(f"frame too small: {w}x{h}")

    r = rgb[..., 0].astype(np.int64)
    g = rgb[..., 1].astype(np.int64)
    b = rgb[..., 2].astype(np.int64)
    yi = 299 * r + 587 * g + 114 * b
    y = yi / 1000.0
    n = h * w

    # Exposure and tonal distribution.
    codes = (yi + 500) // 1000
    hist = np.bincount(codes.ravel(), minlength=256)
    y_mean = float(y.mean())
    y_std = float(np.sqrt(np.mean((y - y_mean) ** 2)))
    p05 = _percentile(hist, n, 0.05)
    p50 = _percentile(hist, n, 0.50)
    p95 = _percentile(hist, n, 0.95)
    dark_frac = float(hist[:DARK_CODE].sum()) / n
    bright_frac = float(hist[BRIGHT_CODE + 1 :].sum()) / n
    probs = hist[hist > 0] / n
    entropy = float(-(probs * np.log2(probs)).sum())

    # Sharpness: 4-neighbour Laplacian on the interior.
    c = y[1:-1, 1:-1]
    lap = y[:-2, 1:-1] + y[2:, 1:-1] + y[1:-1, :-2] + y[1:-1, 2:] - 4.0 * c
    lap_mean = float(lap.mean())
    lap_var = float(np.mean((lap - lap_mean) ** 2))

    # Sobel gradients.
    tl, tc, tr = y[:-2, :-2], y[:-2, 1:-1], y[:-2, 2:]
    ml, mr = y[1:-1, :-2], y[1:-1, 2:]
    bl, bc, br = y[2:, :-2], y[2:, 1:-1], y[2:, 2:]
    gx = (tr + 2.0 * mr + br) - (tl + 2.0 * ml + bl)
    gy = (bl + 2.0 * bc + br) - (tl + 2.0 * tc + tr)
    mag2 = gx * gx + gy * gy
    tenengrad = float(mag2.mean())
    edge_density = float(np.count_nonzero(mag2 > EDGE_THRESHOLD_SQ)) / mag2.size

    # Fine vs. coarse detail, on the region where a 9x9 box is defined.
    box3 = _box_mean(y, 1)
    box9 = _box_mean(y, 4)
    y_r = y[4 : h - 4, 4 : w - 4]
    box3_r = box3[3 : h - 5, 3 : w - 5]
    fine = float(np.abs(y_r - box3_r).mean())
    coarse = float(np.abs(box3_r - box9).mean())
    detail_ratio = fine / (coarse + DETAIL_EPS)

    # Immerkaer (1996) fast noise variance estimate.
    m = (
        tl
        - 2.0 * tc
        + tr
        - 2.0 * ml
        + 4.0 * c
        - 2.0 * mr
        + bl
        - 2.0 * bc
        + br
    )
    sigma = math.sqrt(math.pi / 2.0) * float(np.abs(m).sum()) / (6.0 * (w - 2) * (h - 2))

    # Colour.
    rf = r.astype(np.float64)
    gf = g.astype(np.float64)
    bf = b.astype(np.float64)
    rg = rf - gf
    yb = 0.5 * (rf + gf) - bf
    rg_mean = float(rg.mean())
    yb_mean = float(yb.mean())
    rg_std = float(np.sqrt(np.mean((rg - rg_mean) ** 2)))
    yb_std = float(np.sqrt(np.mean((yb - yb_mean) ** 2)))
    colorfulness = (
        math.sqrt(rg_std * rg_std + yb_std * yb_std)
        + 0.3 * math.sqrt(rg_mean * rg_mean + yb_mean * yb_mean)
    ) / 100.0
    mx = np.maximum(np.maximum(r, g), b)
    mn = np.minimum(np.minimum(r, g), b)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1), 0.0)
    sat_mean = float(sat.mean())

    return np.array(
        [
            math.log1p(lap_var),
            math.log1p(tenengrad),
            detail_ratio,
            edge_density,
            y_mean / 255.0,
            y_std / 255.0,
            p05 / 255.0,
            p50 / 255.0,
            p95 / 255.0,
            dark_frac,
            bright_frac,
            math.log1p(sigma),
            colorfulness,
            sat_mean,
            entropy / 8.0,
        ],
        dtype=np.float64,
    )


def batch_features(frames: list[np.ndarray]) -> np.ndarray:
    return np.stack([frame_features(f) for f in frames]) if frames else np.zeros((0, len(FEATURE_NAMES)))
