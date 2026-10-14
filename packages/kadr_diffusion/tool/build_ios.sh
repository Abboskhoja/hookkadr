#!/usr/bin/env bash
# Builds KadrSd.xcframework (iPhone + simulator) from the pinned
# stable-diffusion.cpp checkout and src/kadr_sd.cpp.
#
#   tool/fetch_sd.sh && tool/build_ios.sh
#
# Metal is enabled for devices when the Xcode Metal Toolchain is installed
# (xcodebuild -downloadComponent MetalToolchain); the simulator is CPU-only.
# Only kadr_sd_* is exported, so the framework's own ggml never clashes with
# the copy inside KadrLlm.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$(pwd)
SD=$ROOT/third_party/stable-diffusion.cpp
OUT=$ROOT/ios/Frameworks
MIN_IOS=16.0

[ -d "$SD" ] || { echo "run tool/fetch_sd.sh first"; exit 1; }

device_metal=OFF
if xcrun -sdk iphoneos metal --version >/dev/null 2>&1; then device_metal=ON; fi

EXPORTS=$ROOT/build/exports.txt
mkdir -p "$ROOT/build"
grep -o 'kadr_sd_[a-z_]*' "$ROOT/src/kadr_sd.h" | sort -u | sed 's/^/_/' > "$EXPORTS"

build_slice() {
  local sdk=$1 metal=$2 target=$3 arch=${4:-arm64}
  local dir=$ROOT/build/ios-$sdk-$arch
  cmake -S "$SD" -B "$dir" -G Ninja \
    -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT="$sdk" -DCMAKE_OSX_ARCHITECTURES=$arch \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=$MIN_IOS -DCMAKE_BUILD_TYPE=Release \
    -DSD_METAL=$metal -DGGML_METAL=$metal -DGGML_METAL_EMBED_LIBRARY=ON -DGGML_NATIVE=OFF -DGGML_OPENMP=OFF \
    -DSD_BUILD_EXAMPLES=OFF -DSD_WEBP=OFF -DSD_WEBM=OFF >/dev/null
  cmake --build "$dir" --target stable-diffusion >/dev/null

  local fw=$dir/KadrSd.framework
  rm -rf "$fw" && mkdir -p "$fw"
  local frameworks=(-framework Foundation -framework Accelerate)
  [ "$metal" = ON ] && frameworks+=(-framework Metal -framework MetalKit)
  xcrun -sdk "$sdk" clang++ -std=c++17 -O2 -dynamiclib -target "$target" \
    -isysroot "$(xcrun -sdk "$sdk" --show-sdk-path)" \
    -I"$ROOT/src" -I"$SD/include" -I"$SD/thirdparty" \
    "$ROOT/src/kadr_sd.cpp" $(find "$dir" -name '*.a' | sort) "${frameworks[@]}" \
    -Wl,-exported_symbols_list,"$EXPORTS" -Wl,-dead_strip \
    -install_name @rpath/KadrSd.framework/KadrSd -o "$fw/KadrSd"
  cat > "$fw/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>KadrSd</string>
  <key>CFBundleIdentifier</key><string>uz.hookkadr.KadrSd</string>
  <key>CFBundleName</key><string>KadrSd</string>
  <key>CFBundlePackageType</key><string>FMWK</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>MinimumOSVersion</key><string>$MIN_IOS</string>
</dict></plist>
PLIST
  echo "$sdk $arch: Metal=$metal"
}

build_slice iphoneos "$device_metal" arm64-apple-ios$MIN_IOS arm64
build_slice iphonesimulator OFF arm64-apple-ios$MIN_IOS-simulator arm64
build_slice iphonesimulator OFF x86_64-apple-ios$MIN_IOS-simulator x86_64

SIM=$ROOT/build/ios-iphonesimulator-universal/KadrSd.framework
rm -rf "$SIM" && mkdir -p "$SIM"
cp "$ROOT/build/ios-iphonesimulator-arm64/KadrSd.framework/Info.plist" "$SIM/"
lipo -create "$ROOT/build/ios-iphonesimulator-arm64/KadrSd.framework/KadrSd" \
  "$ROOT/build/ios-iphonesimulator-x86_64/KadrSd.framework/KadrSd" -output "$SIM/KadrSd"

rm -rf "$OUT/KadrSd.xcframework" && mkdir -p "$OUT"
xcodebuild -create-xcframework \
  -framework "$ROOT/build/ios-iphoneos-arm64/KadrSd.framework" \
  -framework "$SIM" \
  -output "$OUT/KadrSd.xcframework" >/dev/null
echo "built $OUT/KadrSd.xcframework"
