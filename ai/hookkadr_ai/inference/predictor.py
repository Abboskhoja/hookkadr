"""Scene Quality inference on files: FFmpeg analysis frames → features → model."""

from __future__ import annotations

import json
import os
from pathlib import Path

import numpy as np

from ..features.frame_quality import FEATURE_VERSION, batch_features
from ..media.ffmpeg import ANALYSIS_FILTER, TimedFrame, analysis_frames_from_file
from ..models.scene_quality import ArtifactModel


class NoProductionModel(RuntimeError):
    pass


class SceneQualityPredictor:
    def __init__(self, artifact: dict):
        if artifact["input"]["featureVersion"] != FEATURE_VERSION:
            raise ValueError("artifact feature version does not match this code")
        if artifact["input"]["analysisFilter"] != ANALYSIS_FILTER:
            raise ValueError("artifact analysis filter does not match this code")
        self.model = ArtifactModel(artifact)

    @classmethod
    def load(cls, name: str = "scene_quality") -> "SceneQualityPredictor":
        """``$HOOKKADR_MODEL_PATH`` if set, else the registry's production version."""
        path = os.environ.get("HOOKKADR_MODEL_PATH")
        if path:
            return cls(json.loads(Path(path).read_text()))
        from ..registry.model_registry import production_artifact

        artifact = production_artifact(name)
        if artifact is None:
            raise NoProductionModel(f"no production version of {name} — train and promote one first")
        return cls(artifact)

    def score_frames(self, frames: list[TimedFrame]) -> list[dict]:
        if not frames:
            return []
        quality, probs = self.model.predict(batch_features([f.rgb for f in frames]))
        flags = self.model.flags(probs)
        return [
            {
                "timeSec": round(f.time_sec, 3),
                "quality": round(float(quality[i]), 4),
                "defects": {d: round(float(probs[i, j]), 4) for j, d in enumerate(self.model.defects)},
                "flags": flags[i],
            }
            for i, f in enumerate(frames)
        ]

    def score_file(self, path: str, *, every_sec: float = 1.0, max_frames: int = 48) -> dict:
        frames = self.score_frames(analysis_frames_from_file(path, every_sec=every_sec, max_frames=max_frames))
        if not frames:
            raise ValueError("no decodable frames")
        q = np.array([f["quality"] for f in frames])
        worst = frames[int(np.argmin(q))]
        return {
            "model": {"name": self.model.name, "version": self.model.version},
            "frames": frames,
            "summary": {
                "frames": len(frames),
                "meanQuality": round(float(q.mean()), 4),
                "worst": {"timeSec": worst["timeSec"], "quality": worst["quality"], "flags": worst["flags"]},
                "flaggedShare": {
                    d: round(sum(d in f["flags"] for f in frames) / len(frames), 4) for d in self.model.defects
                },
            },
        }
