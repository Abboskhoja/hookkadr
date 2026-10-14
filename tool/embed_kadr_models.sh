#!/bin/sh
# Xcode build phase "Embed Kadr AI Models": copies ios/KadrModels (prepared
# by tool/bundle_kadr_models.sh) into the app bundle. Nothing to do when the
# folder is absent, so normal builds are unaffected.
SRC="${SRCROOT}/KadrModels"
[ -d "$SRC" ] || exit 0
ls "$SRC" | grep -qv '\.sha256$' || exit 0
DST="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/KadrModels"
mkdir -p "$DST"
rsync -a --delete --exclude '*.sha256' "$SRC/" "$DST/"
echo "Embedded Kadr AI models: $(du -sh "$DST" | cut -f1)"
