"""HOOKKADR AI inference service (internal; the Node API and workers call it).

Run::

    uv run uvicorn hookkadr_ai.inference.service:app --host 127.0.0.1 --port 8790

Set ``HOOKKADR_AI_TOKEN`` to require ``Authorization: Bearer <token>``.
"""

from __future__ import annotations

import hmac
import os
import tempfile
from contextlib import asynccontextmanager

from fastapi import FastAPI, File, Form, Header, HTTPException, UploadFile

from ..media.ffmpeg import FFmpegError
from .predictor import NoProductionModel, SceneQualityPredictor

MAX_UPLOAD_BYTES = int(os.environ.get("HOOKKADR_AI_MAX_UPLOAD", 64 * 1024 * 1024))
ALLOWED_TYPES = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
    "video/mp4": ".mp4",
    "video/quicktime": ".mov",
    "video/webm": ".webm",
}

_state: dict[str, object] = {}


def _predictor() -> SceneQualityPredictor:
    p = _state.get("scene_quality")
    if isinstance(p, SceneQualityPredictor):
        return p
    try:
        p = SceneQualityPredictor.load()
    except NoProductionModel as e:
        raise HTTPException(503, str(e)) from e
    _state["scene_quality"] = p
    return p


@asynccontextmanager
async def lifespan(_: FastAPI):
    try:
        _state["scene_quality"] = SceneQualityPredictor.load()
    except NoProductionModel:
        pass  # endpoints answer 503 until a model is promoted
    yield
    _state.clear()


app = FastAPI(title="HOOKKADR AI", version="0.1.0", lifespan=lifespan)


def _auth(authorization: str | None) -> None:
    token = os.environ.get("HOOKKADR_AI_TOKEN")
    if token and not hmac.compare_digest(authorization or "", f"Bearer {token}"):
        raise HTTPException(401, "unauthorized")


@app.get("/healthz")
def healthz() -> dict:
    p = _state.get("scene_quality")
    return {"ok": True, "models": {"scene_quality": p.model.version if isinstance(p, SceneQualityPredictor) else None}}


@app.get("/v1/models")
def models(authorization: str | None = Header(default=None)) -> dict:
    _auth(authorization)
    from ..registry.model_registry import _load

    out = []
    for name, m in _load()["models"].items():
        out.append(
            {
                "name": name,
                "production": m["production"],
                "versions": [{k: v[k] for k in ("version", "status", "dataset", "metrics")} for v in m["versions"]],
            }
        )
    return {"models": out}


@app.post("/v1/vision/scene-quality")
def scene_quality(
    file: UploadFile = File(...),
    every_sec: float = Form(1.0, alias="everySec", gt=0.1, le=30.0),
    max_frames: int = Form(48, alias="maxFrames", ge=1, le=240),
    authorization: str | None = Header(default=None),
) -> dict:
    _auth(authorization)
    suffix = ALLOWED_TYPES.get((file.content_type or "").split(";")[0].strip())
    if suffix is None:
        raise HTTPException(415, f"unsupported media type {file.content_type}")
    predictor = _predictor()
    with tempfile.NamedTemporaryFile(suffix=suffix) as tmp:
        size = 0
        while chunk := file.file.read(1 << 20):
            size += len(chunk)
            if size > MAX_UPLOAD_BYTES:
                raise HTTPException(413, f"file larger than {MAX_UPLOAD_BYTES} bytes")
            tmp.write(chunk)
        tmp.flush()
        try:
            return predictor.score_file(tmp.name, every_sec=every_sec, max_frames=max_frames)
        except (FFmpegError, ValueError) as e:
            raise HTTPException(400, f"could not analyse media: {str(e)[:200]}") from e

