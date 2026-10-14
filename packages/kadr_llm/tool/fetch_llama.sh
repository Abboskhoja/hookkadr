#!/usr/bin/env bash
# Fetches the pinned llama.cpp release used by Kadr AI (MIT licence).
# b11429 is the first build verified to run Gemma 4 E2B in this project.
set -euo pipefail
cd "$(dirname "$0")/.."
TAG=b11429
COMMIT=d812350
if [ -d third_party/llama.cpp ]; then
  have=$(git -C third_party/llama.cpp rev-parse --short=7 HEAD)
  [ "$have" = "$COMMIT" ] && { echo "llama.cpp $TAG present"; exit 0; }
  echo "third_party/llama.cpp is at $have, expected $COMMIT"; exit 1
fi
mkdir -p third_party
git clone --depth 1 --branch "$TAG" https://github.com/ggml-org/llama.cpp.git third_party/llama.cpp
[ "$(git -C third_party/llama.cpp rev-parse --short=7 HEAD)" = "$COMMIT" ] || { echo "unexpected commit"; exit 1; }
