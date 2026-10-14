import subprocess

import numpy as np
import pytest

from conftest import pattern_rgb
from hookkadr_ai.media.ffmpeg import (
    FFmpegError,
    analysis_frames_from_file,
    analysis_frames_from_rgb,
    ffmpeg_exe,
    parse_ppm_stream,
)


def test_parse_ppm_stream_with_comment_and_two_frames():
    a = np.arange(2 * 3 * 3, dtype=np.uint8).reshape(2, 3, 3)
    b = np.full((1, 2, 3), 9, np.uint8)
    data = b"P6\n# hi\n3 2\n255\n" + a.tobytes() + b"P6 2 1 255\n" + b.tobytes()
    frames = parse_ppm_stream(data)
    assert [f.shape for f in frames] == [(2, 3, 3), (1, 2, 3)]
    assert np.array_equal(frames[0], a) and np.array_equal(frames[1], b)


def test_parse_ppm_rejects_truncated():
    with pytest.raises(FFmpegError):
        parse_ppm_stream(b"P6 4 4 255\n" + b"\0" * 10)


def test_analysis_size_keeps_aspect():
    land = analysis_frames_from_rgb([np.zeros((720, 1280, 3), np.uint8)] * 2)
    port = analysis_frames_from_rgb([np.zeros((1280, 720, 3), np.uint8)])
    assert [f.shape for f in land] == [(216, 384, 3)] * 2
    assert port[0].shape == (384, 216, 3)


def test_video_and_still_files(tmp_path):
    video = tmp_path / "clip.mp4"
    subprocess.run(
        [ffmpeg_exe(), "-hide_banner", "-loglevel", "error", "-f", "lavfi", "-i", "testsrc=size=640x360:rate=25:duration=3",
         "-pix_fmt", "yuv420p", str(video)],
        check=True,
    )
    frames = analysis_frames_from_file(str(video), every_sec=1.0)
    assert [f.time_sec for f in frames] == [0.0, 1.0, 2.0]
    assert frames[0].rgb.shape == (216, 384, 3)

    still = tmp_path / "still.png"
    import cv2

    cv2.imwrite(str(still), pattern_rgb(300, 500))
    frames = analysis_frames_from_file(str(still))
    assert len(frames) == 1 and frames[0].rgb.shape == (230, 384, 3)


def test_short_video_preserves_a_frame_and_respects_limit(tmp_path):
    video = tmp_path / "short.mp4"
    subprocess.run(
        [ffmpeg_exe(), "-hide_banner", "-loglevel", "error", "-f", "lavfi", "-i",
         "testsrc=size=320x180:rate=25:duration=0.12", "-pix_fmt", "yuv420p", str(video)],
        check=True,
    )
    frames = analysis_frames_from_file(str(video), every_sec=2, max_frames=1)
    assert len(frames) == 1
    assert frames[0].time_sec == 0.0


@pytest.mark.parametrize("interval", [0, -1, float("nan"), float("inf")])
def test_invalid_sampling_interval(interval):
    with pytest.raises(ValueError, match="finite and positive"):
        analysis_frames_from_file("unused", every_sec=interval)


@pytest.mark.parametrize("limit", [0, -1, 1.5, True])
def test_invalid_frame_limit(limit):
    with pytest.raises(ValueError, match="positive integer"):
        analysis_frames_from_file("unused", max_frames=limit)
