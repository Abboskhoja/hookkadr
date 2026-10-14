"""Controlled picture defects with known labels (self-supervised labelling).

A clean, licensed photo is turned into a "video frame" with zero, one or two
defects of known severity ``s`` in [0, 1]. A defect is labelled present when
``s >= POSITIVE_SEVERITY``; milder versions stay in the data as negatives so
the model learns where "soft" turns into "blurry". The quality target is
``prod(1 - 0.9 * s)`` over the applied defects (1.0 for a clean frame).

This is a proxy for human judgement, not a replacement: production versions
need frames rated by people (see the model card).

All parameters are calibrated at the 1280x720 working resolution.
"""

from __future__ import annotations

from dataclasses import dataclass, field

import cv2
import numpy as np

DEFECTS: tuple[str, ...] = ("blurry", "dark", "overexposed", "noisy", "low_contrast")
POSITIVE_SEVERITY = 0.3

KINDS: tuple[str, ...] = ("blur_gauss", "blur_motion", "dark", "overexposed", "noise", "low_contrast")
DEFECT_OF = {
    "blur_gauss": "blurry",
    "blur_motion": "blurry",
    "dark": "dark",
    "overexposed": "overexposed",
    "noise": "noisy",
    "low_contrast": "low_contrast",
}
# Physical order: haze in the scene, optics/motion, exposure, sensor noise.
ORDER = ("low_contrast", "blur_gauss", "blur_motion", "dark", "overexposed", "noise")
INCOMPATIBLE = (frozenset({"dark", "overexposed"}), frozenset({"blur_gauss", "blur_motion"}))


@dataclass
class Op:
    kind: str
    severity: float
    params: dict = field(default_factory=dict)


def srgb_to_linear(x: np.ndarray) -> np.ndarray:
    return np.where(x <= 0.04045, x / 12.92, ((x + 0.055) / 1.055) ** 2.4)


def linear_to_srgb(x: np.ndarray) -> np.ndarray:
    x = np.clip(x, 0.0, 1.0)
    return np.where(x <= 0.0031308, 12.92 * x, 1.055 * np.power(x, 1 / 2.4) - 0.055)


def _motion_kernel(length: float, angle_deg: float) -> np.ndarray:
    size = max(3, int(np.ceil(length)) | 1)
    k = np.zeros((size, size), np.float32)
    c = size // 2
    half = (length - 1) / 2
    for t in np.linspace(-half, half, max(2, int(np.ceil(length)) * 4)):
        x = c + t * np.cos(np.deg2rad(angle_deg))
        y = c + t * np.sin(np.deg2rad(angle_deg))
        x0, y0 = int(np.floor(x)), int(np.floor(y))
        fx, fy = x - x0, y - y0
        for dx, dy, wgt in ((0, 0, (1 - fx) * (1 - fy)), (1, 0, fx * (1 - fy)), (0, 1, (1 - fx) * fy), (1, 1, fx * fy)):
            if 0 <= x0 + dx < size and 0 <= y0 + dy < size:
                k[y0 + dy, x0 + dx] += wgt
    return k / k.sum()


def apply_op(img: np.ndarray, op: Op, rng: np.random.Generator) -> np.ndarray:
    """``img``: float32 sRGB in [0, 1], HxWx3. Records the concrete parameters in ``op.params``."""
    s = op.severity
    if op.kind == "blur_gauss":
        sigma = 0.3 + 5.7 * s
        op.params = {"sigma_px": round(sigma, 3)}
        return cv2.GaussianBlur(img, (0, 0), sigma)
    if op.kind == "blur_motion":
        length = 1.0 + 35.0 * s
        angle = float(rng.uniform(0, 180))
        op.params = {"length_px": round(length, 2), "angle_deg": round(angle, 1)}
        return cv2.filter2D(img, -1, _motion_kernel(length, angle), borderType=cv2.BORDER_REFLECT)
    if op.kind == "dark":
        ev = -4.0 * s
        op.params = {"ev": round(ev, 3)}
        return linear_to_srgb(srgb_to_linear(img) * 2.0**ev).astype(np.float32)
    if op.kind == "overexposed":
        ev = 3.0 * s
        op.params = {"ev": round(ev, 3)}
        return linear_to_srgb(srgb_to_linear(img) * 2.0**ev).astype(np.float32)
    if op.kind == "noise":
        sigma = 0.2 * s
        op.params = {"sigma": round(sigma, 4)}
        noise = rng.normal(0.0, sigma, img.shape).astype(np.float32)
        return np.clip(img + noise, 0.0, 1.0)
    if op.kind == "low_contrast":
        amount = 0.15 + 0.6 * s
        level = float(rng.uniform(0.45, 0.85))
        tint = rng.uniform(-0.03, 0.03, 3).astype(np.float32)
        op.params = {"amount": round(amount, 3), "haze_level": round(level, 3)}
        haze = np.clip(level + tint, 0.0, 1.0)
        return (img * (1.0 - amount) + haze * amount).astype(np.float32)
    raise ValueError(f"unknown defect kind {op.kind}")


def sample_ops(rng: np.random.Generator) -> list[Op]:
    """One defect (65%) or two compatible ones, each with uniform severity."""
    count = 1 if rng.random() < 0.65 else 2
    kinds: list[str] = []
    while len(kinds) < count:
        k = KINDS[int(rng.integers(len(KINDS)))]
        if k in kinds or any(frozenset({k, o}) in INCOMPATIBLE for o in kinds):
            continue
        kinds.append(k)
    return [Op(k, float(rng.uniform(0.0, 1.0))) for k in kinds]


def labels_of(ops: list[Op]) -> tuple[np.ndarray, float]:
    y = np.zeros(len(DEFECTS), np.float32)
    q = 1.0
    for op in ops:
        if op.severity >= POSITIVE_SEVERITY:
            y[DEFECTS.index(DEFECT_OF[op.kind])] = 1.0
        q *= 1.0 - 0.9 * op.severity
    return y, float(q)


def degrade(img: np.ndarray, ops: list[Op], rng: np.random.Generator) -> np.ndarray:
    out = img
    for kind in ORDER:
        for op in ops:
            if op.kind == kind:
                out = apply_op(out, op, rng)
    return np.clip(out, 0.0, 1.0).astype(np.float32)


def jpeg_roundtrip(rgb: np.ndarray, quality: int) -> np.ndarray:
    """Codec nuisance applied to every sample (uint8 RGB in, uint8 RGB out)."""
    ok, buf = cv2.imencode(".jpg", cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR), [cv2.IMWRITE_JPEG_QUALITY, int(quality)])
    if not ok:
        raise RuntimeError("jpeg encode failed")
    return cv2.cvtColor(cv2.imdecode(buf, cv2.IMREAD_COLOR), cv2.COLOR_BGR2RGB)
