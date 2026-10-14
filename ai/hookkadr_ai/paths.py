"""Filesystem layout of the AI workspace (everything lives under ``ai/``)."""

from pathlib import Path

AI_ROOT = Path(__file__).resolve().parent.parent
REPO_ROOT = AI_ROOT.parent

CONFIGS_DIR = AI_ROOT / "configs"
# Downloaded sources and built datasets: large, reproducible, never committed.
DATA_DIR = AI_ROOT / "data"
SOURCES_DIR = DATA_DIR / "sources"
DATASETS_DIR = DATA_DIR / "datasets"
# Training runs: checkpoints, logs, exported candidates. Not committed.
RUNS_DIR = AI_ROOT / "runs"
# Dataset/model registries and promoted model artifacts. Committed.
REGISTRY_DIR = AI_ROOT / "registry"

# Where the Flutter app reads the production model and the parity goldens.
APP_MODELS_DIR = REPO_ROOT / "assets" / "models"
APP_TEST_FIXTURES_DIR = REPO_ROOT / "test" / "fixtures"
