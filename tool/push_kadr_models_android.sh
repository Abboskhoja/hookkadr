#!/usr/bin/env bash
# Puts Kadr AI's model packs on an Android phone BEFORE first launch, so a
# direct/sideloaded install (like `flutter run` or `adb install`) works with
# nothing to download — the Android equivalent of tool/bundle_kadr_models.sh.
#
#   tool/push_kadr_models_android.sh <dir with the model files> [-s DEVICE]
#
# Every file is checked against the catalog's SHA-256 (the same values as
# lib/features/kadr_ai/model_catalog.dart; test/kadr_bundle_test.dart keeps
# them in sync), then `adb push`ed to the app's own external files dir
# (no storage permission needed on API 19+). KadrModelManager looks there
# first on Android and uses a file in place — no copy, no install.
#
# Note: unlike iOS, Android has no store-imposed size cap we hit here — but a
# 6+ GB APK still isn't something Google Play or a mobile network can hand a
# user, so Play Store builds still rely on the app's automatic first-run
# setup over Wi-Fi. This script is for direct installs and testing.
set -euo pipefail
SRC=${1:?usage: tool/push_kadr_models_android.sh <dir with model files> [-s DEVICE]}
shift || true
cd "$(dirname "$0")/.."

ADB=$(command -v adb || echo /opt/homebrew/share/android-commandlinetools/platform-tools/adb)
[ -x "$ADB" ] || { echo "adb not found (set PATH or install Android platform-tools)"; exit 1; }

PKG=com.hookkadr.hookkadr
DEST="/sdcard/Android/data/$PKG/files/KadrModels"
"$ADB" "$@" shell mkdir -p "$DEST"

# file name | sha256 | size — kept in sync with model_catalog.dart by
# test/kadr_bundle_test.dart, same as tool/bundle_kadr_models.sh.
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
  # || true: a missing remote file is the normal first-push case, not a
  # script error — `adb shell` forwards the remote stat's exit code, and
  # set -e would otherwise kill the whole loop right here.
  remote=$("$ADB" "$@" shell "stat -c %s '$DEST/$name' 2>/dev/null || true" | tr -d '\r')
  if [ "$remote" = "$size" ]; then
    echo "ok (already on device): $name"; continue
  fi
  got=$(shasum -a 256 "$src" | cut -d' ' -f1)
  [ "$got" = "$sha" ] || { echo "SHA-256 MISMATCH: $name"; exit 1; }
  echo "pushing: $name ($((size / 1024 / 1024)) MB)"
  "$ADB" "$@" push "$src" "$DEST/$name" >/dev/null
done
"$ADB" "$@" shell du -sh "$DEST" 2>/dev/null || true
echo "done — (re)install the app and it starts with Kadr AI already in place."
