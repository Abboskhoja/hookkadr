# KART AI local model laboratory

This directory contains an original, trained technical-frame-quality model and
the dataset, training, evaluation, registry, rollback and inference code used to
produce it. It is a small working foundation, not a trained multimodal foundation
model. No external inference API or GPU is required for this model.

## Verified artifact

`registry/artifacts/scene_quality/1.0.0/` contains the model card, weights in JSON,
and evaluation report. `assets/models/scene_quality.json` is the mobile copy;
`test/fixtures/scene_quality_golden.json` checks Python/Dart numerical parity.

Architecture: 15 measured image features → 32 → 32 → 6, ReLU hidden layers,
sigmoid outputs. Initialized from scratch in PyTorch. Outputs: technical quality
and blur, darkness, overexposure, noise and low-contrast probabilities.

Run `scene_quality/20261014-030042` used 4,496 controlled-degradation samples:
2,936 train, 576 validation, 984 held-out test. Splits group variants by source
photo. The selected source manifest contains 335 CC0/public-domain-labelled
photos; source pages, author, licence metadata and hashes are retained in
`registry/source_manifests/`. These labels do not cover unrelated image/personality
rights, and no claims about unrestricted use of arbitrary web media are made.

| Held-out metric | Trained model | Deterministic baseline |
|---|---:|---:|
| Macro defect AUC | 0.982965 | 0.942852 |
| Macro defect F1 | 0.861521 | 0.732267 |
| Quality Spearman | 0.823179 | See evaluation report |

The original promotion thresholds were retained: AUC gain ≥0.02 and quality
Spearman ≥0.7. Both passed. `production` in the local registry means the selected
inference artifact; it does not certify the entire application for production.
No quality gate was loosened to accept this run.

The quality target is derived from synthetic degradation severity. This model
does **not** judge creativity, storytelling, product fidelity or virality. It has
not been validated against human ratings of real customer videos. Night scenes,
intentional blur and compression/HDR artifacts require further evaluation.

## Reproduce locally

Tested with Python 3.12.15; exact installed Python package versions are recorded
in `requirements-lock.txt` (local CPU/macOS environment). CUDA deployment needs
its own tested lock and hardware profile.

From `ai/`, with a Python 3.12 environment containing the locked dependencies:

```sh
python -m pip install -r requirements-lock.txt
python -m pytest -q
python -m hookkadr_ai.datasets.build --config configs/scene_quality_v1.json --workers 4
python -m hookkadr_ai.training.train --config configs/scene_quality_v1.json
python -m hookkadr_ai.registry.model_registry list
```

The build requires the source files and manifest at `data/sources/commons/`.
They already exist locally for the recorded run. A fresh checkout must restore
that snapshot; `python -m hookkadr_ai.datasets.sources` downloads source media
and therefore requires network access. Source availability may change; inspect
hashes and licences when recreating it. Data, virtual environments and training
runs are ignored by Git. The source manifest snapshot and released JSON model
remain versionable.

Training writes `runs/scene_quality/<run-id>/checkpoints/best.pt`, `last.pt`,
`artifact/model.json`, logs and `eval.json`. The recorded run's files exist
locally; checkpoints are deliberately not mobile assets. New released training
runs must bump the version in a copied configuration before registration:

```sh
python -m hookkadr_ai.registry.model_registry register --run runs/scene_quality/<run-id>
python -m hookkadr_ai.registry.model_registry promote --model scene_quality --version <new-version>
python -m hookkadr_ai.registry.model_registry rollback --model scene_quality
```

Rollback requires a previously archived version; the first release has none.
Registration is not promotion. A rejected candidate must never replace the
selected model. Evaluation uses source-disjoint validation and test splits;
normalization and optimization use training data, thresholds use validation.

## Inference

From `ai/`:

```sh
python -m uvicorn hookkadr_ai.inference.service:app --host 127.0.0.1 --port 8790
curl -F 'file=@/absolute/path/video.mp4' -F everySec=2 -F maxFrames=12 \
  http://127.0.0.1:8790/v1/vision/scene-quality
```

`GET /healthz` and `GET /v1/models` report loaded/registered versions. The media
endpoint returns sampled timestamps, probabilities, thresholded flags and
summary metrics. Invalid files fail; missing models return 503. The default
service is local-only. Before exposing it beyond localhost, configure
`HOOKKADR_AI_TOKEN` and a gateway with authentication, upload limits, worker
timeouts and a queue. The upload-size check in this service does not replace a
gateway limit. This task does not deploy a GPU service or public endpoint.

Mobile inference uses the same FFmpeg pixel transform and dense weights offline.
In the editor, KART AI → “Sifatni tekshir” samples up to 12 frames from the first
24 seconds of each of the first four attached media files. It reports technical
scores; it does not automatically remove clips based on these experimental scores.

## Verification

From the repository root:

```sh
flutter test test/scene_quality_test.dart test/scene_quality_scanner_test.dart
flutter test integration_test/kart_production_test.dart -d <device-id>
```

The integration test creates a labelled synthetic source, compiles a creative
brief into a timeline, renders an MP4, probes its size/duration/FPS, and executes
the actual bundled model on decoded output frames. Synthetic test media is never
presented as a generated commercial.
