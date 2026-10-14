"""API contract checks using fixture weights, never model-quality evidence."""

import io

import pytest
from fastapi.testclient import TestClient
from PIL import Image

from hookkadr_ai.inference import service
from hookkadr_ai.inference.predictor import NoProductionModel, SceneQualityPredictor


@pytest.fixture
def client(monkeypatch, artifact):
    predictor = SceneQualityPredictor(artifact)
    monkeypatch.setattr(SceneQualityPredictor, "load", lambda: predictor)
    monkeypatch.setenv("HOOKKADR_AI_TOKEN", "test-token")
    with TestClient(service.app) as client:
        yield client


def still_png():
    file = io.BytesIO()
    Image.new("RGB", (96, 64), (120, 130, 140)).save(file, format="PNG")
    return file.getvalue()


def test_image_endpoint_runs_real_ffmpeg_and_inference(client):
    response = client.post(
        "/v1/vision/scene-quality",
        headers={"Authorization": "Bearer test-token"},
        files={"file": ("frame.png", still_png(), "image/png")},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["model"] == {"name": "scene_quality", "version": "0.0.1"}
    assert body["summary"]["frames"] == 1
    assert body["frames"][0]["timeSec"] == 0
    assert 0 <= body["frames"][0]["quality"] <= 1
    assert set(body["frames"][0]["defects"]) == {
        "blurry", "dark", "overexposed", "noisy", "low_contrast"
    }


def test_endpoint_requires_configured_token(client):
    response = client.post(
        "/v1/vision/scene-quality",
        files={"file": ("frame.png", still_png(), "image/png")},
    )
    assert response.status_code == 401


@pytest.mark.parametrize("media_type,content,status", [
    ("text/plain", b"hello", 415),
    ("image/png", b"not an image", 400),
])
def test_endpoint_rejects_invalid_media(client, media_type, content, status):
    response = client.post(
        "/v1/vision/scene-quality",
        headers={"Authorization": "Bearer test-token"},
        files={"file": ("file", content, media_type)},
    )
    assert response.status_code == status


def test_missing_production_model_is_unavailable(monkeypatch):
    def unavailable():
        raise NoProductionModel("no production model")

    monkeypatch.setattr(SceneQualityPredictor, "load", unavailable)
    monkeypatch.delenv("HOOKKADR_AI_TOKEN", raising=False)
    with TestClient(service.app) as client:
        response = client.post(
            "/v1/vision/scene-quality",
            files={"file": ("frame.png", still_png(), "image/png")},
        )
    assert response.status_code == 503


def test_endpoint_enforces_upload_limit(client, monkeypatch):
    monkeypatch.setattr(service, "MAX_UPLOAD_BYTES", 10)
    response = client.post(
        "/v1/vision/scene-quality",
        headers={"Authorization": "Bearer test-token"},
        files={"file": ("frame.png", still_png(), "image/png")},
    )
    assert response.status_code == 413
