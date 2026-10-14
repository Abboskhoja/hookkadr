#!/usr/bin/env bash
# Puts Kadr AI's model packs inside the iOS app, so it works on first launch
# with nothing to install:
#
#   tool/bundle_kadr_models.sh <dir with the model files>
#
# Every file is checked against the catalog's SHA-256 (the same values as
# lib/features/kadr_ai/model_catalog.dart; test/kadr_bundle_test.dart keeps
# them in sync) and hard-linked (or copied) into ios/KadrModels/. The Xcode
# phase "Embed Kadr AI Models" copies that folder into Runner.app.
#
# Note: the App Store limits an iOS app to 4 GB, and all packs together are
# about 6.2 GB. Store builds therefore rely on the app's automatic first-run
# setup; a bundled build is for direct/enterprise installs and testing.
set -euo pipefail
SRC=${1:?usage: tool/bundle_kadr_models.sh <dir with model files>}
cd "$(dirname "$0")/.."
OUT=ios/KadrModels
mkdir -p "$OUT"

# file name | sha256 | size
PACKS=(
  "gemma-4-E2B-it-Q4_K_M.gguf|740185b21d22ceb83a11c3aa62ad5842ef32c70f6096d756bbee85a1e4ec34b8|3106738272"
  "DreamShaper8_LCM.safetensors|a4f3e1526c5dc4fcbe342f5c410d83ae202c7a415fcefcbb92e0f93fcd0a87c3|2133804992"
  "taesd.safetensors|db169d69145ec4ff064e49d99c95fa05d3eb04ee453de35824a6d0f325513549|9793292"
  "animatediff_lightning_4step_comfyui.safetensors|aeb66ae8ff4a868d31379c3bde3e5e7e510a4d4b565a06ee4f1297e93a561dc5|908929664"
)

for entry in "${PACKS[@]}"; do
  IFS='|' read -r name sha size <<<"$entry"
  src="$SRC/$name"
  if [ ! -f "$src" ]; then echo "skip (not found): $name"; continue; fi
  have=$(stat -L -f %z "$src" 2>/dev/null || stat -L -c %s "$src")
  [ "$have" = "$size" ] || { echo "WRONG SIZE: $name ($have != $size)"; exit 1; }
  if [ -f "$OUT/$name" ] && [ "$(stat -L -f %z "$OUT/$name" 2>/dev/null || stat -L -c %s "$OUT/$name")" = "$size" ] \
     && [ -f "$OUT/$name.sha256" ] && [ "$(cat "$OUT/$name.sha256")" = "$sha" ]; then
    echo "ok (already bundled): $name"; continue
  fi
  got=$(shasum -a 256 "$src" | cut -d' ' -f1)
  [ "$got" = "$sha" ] || { echo "SHA-256 MISMATCH: $name"; exit 1; }
  rm -f "$OUT/$name"
  real=$(realpath "$src")
  ln "$real" "$OUT/$name" 2>/dev/null || cp "$real" "$OUT/$name"
  echo "$sha" > "$OUT/$name.sha256"
  echo "bundled: $name"
done
du -sh "$OUT"
