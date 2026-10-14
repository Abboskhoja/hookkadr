#!/usr/bin/env bash
# Fetches the pinned stable-diffusion.cpp release used by Kadr AI's painter
# (MIT licence) together with its ggml submodule.
set -euo pipefail
cd "$(dirname "$0")/.."
TAG=master-929-3f8527a
COMMIT=3f8527a
SRC=third_party/stable-diffusion.cpp
PATCHES=$(pwd)/tool/patches

# Local fixes to the vendored ggml (see each patch's header). Idempotent.
apply_patches() {
  for p in "$PATCHES"/ggml-*.patch; do
    if git -C "$SRC/ggml" apply --check -R "$p" 2>/dev/null; then
      echo "already applied: $(basename "$p")"
    else
      git -C "$SRC/ggml" apply "$p" && echo "applied: $(basename "$p")"
    fi
  done
}

if [ -d "$SRC" ]; then
  have=$(git -C "$SRC" rev-parse --short=7 HEAD)
  [ "$have" = "$COMMIT" ] || { echo "$SRC is at $have, expected $COMMIT"; exit 1; }
  echo "stable-diffusion.cpp $TAG present"
  apply_patches
  exit 0
fi
mkdir -p third_party
git clone --depth 1 --branch "$TAG" --recurse-submodules --shallow-submodules \
  https://github.com/leejet/stable-diffusion.cpp.git "$SRC"
[ "$(git -C "$SRC" rev-parse --short=7 HEAD)" = "$COMMIT" ] || { echo "unexpected commit"; exit 1; }
apply_patches
