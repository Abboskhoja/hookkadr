"""FFmpeg access for analysis frames.

Training, the inference service and the phone all reduce a picture to an
"analysis frame" with the same FFmpeg filter chain, so the model sees the same
kind of pixels everywhere. The Dart side uses ``analysisFilter`` from the model
artifact, which is written from :data:`ANALYSIS_FILTER`.
"""

from __future__ import annotations

import math
import os
import subprocess
from dataclasses import dataclass

import numpy as np

ANALYSIS_LONG_SIDE = 384
# yuv420p first: stills get the same chroma subsampling as decoded video.
ANALYSIS_FILTER = (
    "format=yuv420p,"
    f"scale=w={ANALYSIS_LONG_SIDE}:h={ANALYSIS_LONG_SIDE}"
    ":force_original_aspect_ratio=decrease:flags=area,"
    "format=rgb24"
)


class FFmpegError(RuntimeError):
    pass


def ffmpeg_exe() -> str:
    """The ffmpeg binary: ``$HOOKKADR_FFMPEG`` or the one bundled with imageio-ffmpeg."""
    env = os.environ.get("HOOKKADR_FFMPEG")
    if env:
        return env
    import imageio_ffmpeg

    return imageio_ffmpeg.get_ffmpeg_exe()


def parse_ppm_stream(data: bytes) -> list[np.ndarray]:
    """Splits concatenated binary PPM (P6, maxval 255) images into RGB arrays."""
    frames: list[np.ndarray] = []
    pos = 0
    size = len(data)

    def token() -> bytes:
        nonlocal pos
        while pos < size:
            ch = data[pos : pos + 1]
            if ch == b"#":
                while pos < size and data[pos : pos + 1] not in (b"\n", b"\r"):
                    pos += 1
            elif ch.isspace():
                pos += 1
            else:
                break
        start = pos
        while pos < size and not data[pos : pos + 1].isspace():
            pos += 1
        return data[start:pos]

    while pos < size:
        magic = token()
        if not magic:
            break
        if magic != b"P6":
            raise FFmpegError(f"unexpected image header {magic!r}")
        w, h, maxval = int(token()), int(token()), int(token())
        if maxval != 255:
            raise FFmpegError("only 8-bit PPM is supported")
        pos += 1  # single whitespace after maxval
        end = pos + w * h * 3
        if end > size:
            raise FFmpegError("truncated PPM frame")
        frames.append(np.frombuffer(data, dtype=np.uint8, count=w * h * 3, offset=pos).reshape(h, w, 3).copy())
        pos = end
    return frames


def _run(args: list[str], stdin: bytes | None = None) -> bytes:
    proc = subprocess.run(
        [ffmpeg_exe(), "-hide_banner", "-loglevel", "error", *args],
        input=stdin,
        capture_output=True,
        check=False,
    )
    if proc.returncode != 0:
        raise FFmpegError(proc.stderr.decode("utf-8", "replace").strip()[-400:] or "ffmpeg failed")
    return proc.stdout


def analysis_frames_from_rgb(frames: list[np.ndarray]) -> list[np.ndarray]:
    """Reduces equally sized RGB frames (uint8) to analysis frames in one ffmpeg call."""
    if not frames:
        return []
    h, w, _ = frames[0].shape
    if any(f.shape != (h, w, 3) or f.dtype != np.uint8 for f in frames):
        raise ValueError("frames must be uint8 RGB with equal sizes")
    raw = b"".join(np.ascontiguousarray(f).tobytes() for f in frames)
    out = _run(
        [
            "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{w}x{h}", "-i", "-",
            "-vf", ANALYSIS_FILTER, "-c:v", "ppm", "-f", "image2pipe", "-",
        ],
        stdin=raw,
    )
    result = parse_ppm_stream(out)
    if len(result) != len(frames):
        raise FFmpegError(f"expected {len(frames)} frames, got {len(result)}")
    return result


@dataclass(frozen=True)
class TimedFrame:
    time_sec: float
    rgb: np.ndarray


def analysis_frames_from_file(path: str, *, every_sec: float = 1.0, max_frames: int = 48) -> list[TimedFrame]:
    """Analysis frames of an image or video file.

    A still image yields one frame at 0 s. A video yields one frame every
    ``every_sec`` seconds (FFmpeg ``fps`` filter), at most ``max_frames``.
    """
    if not math.isfinite(every_sec) or every_sec <= 0:
        raise ValueError("every_sec must be finite and positive")
    if not isinstance(max_frames, int) or isinstance(max_frames, bool) or max_frames < 1:
        raise ValueError("max_frames must be a positive integer")
    out = _run(
        [
            "-i", path,
            # Keep the last partial sampling interval, including single-frame
            # images and videos shorter than every_sec. The default FPS EOF
            # rounding can otherwise discard the only decoded frame.
            "-vf", f"fps=1/{every_sec:g}:start_time=0:eof_action=pass,{ANALYSIS_FILTER}",
            "-frames:v", str(max_frames),
            "-c:v", "ppm", "-f", "image2pipe", "-",
        ]
    )
    return [TimedFrame(i * every_sec, f) for i, f in enumerate(parse_ppm_stream(out))]
