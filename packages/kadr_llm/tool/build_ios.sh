#!/usr/bin/env bash
# Builds KadrLlm.xcframework (iPhone + Apple-silicon simulator) from the
# pinned llama.cpp checkout and src/kadr_llm.cpp.
#
#   tool/fetch_llama.sh && tool/build_ios.sh
#
# Metal is enabled for devices when the Xcode Metal Toolchain is installed
# (xcodebuild -downloadComponent MetalToolchain); the simulator is CPU-only.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$(pwd)
LLAMA=$ROOT/third_party/llama.cpp
OUT=$ROOT/ios/Frameworks
MIN_IOS=16.0

[ -d "$LLAMA" ] || { echo "run tool/fetch_llama.sh first"; exit 1; }

device_metal=OFF
if xcrun -sdk iphoneos metal --version >/dev/null 2>&1; then device_metal=ON; fi

build_slice() {
  local sdk=$1 metal=$2 target=$3 arch=${4:-arm64}
  local dir=$ROOT/build/ios-$sdk-$arch
  cmake -S "$LLAMA" -B "$dir" -G Ninja \
    -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT="$sdk" -DCMAKE_OSX_ARCHITECTURES=$arch \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=$MIN_IOS -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
    -DGGML_METAL=$metal -DGGML_METAL_EMBED_LIBRARY=ON -DGGML_NATIVE=OFF -DGGML_OPENMP=OFF \
    -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF -DLLAMA_BUILD_SERVER=OFF \
    -DLLAMA_BUILD_TOOLS=OFF -DLLAMA_CURL=OFF >/dev/null
  cmake --build "$dir" --target llama >/dev/null

  local fw=$dir/KadrLlm.framework
  rm -rf "$fw" && mkdir -p "$fw"
  local frameworks=(-framework Foundation -framework Accelerate)
  [ "$metal" = ON ] && frameworks+=(-framework Metal -framework MetalKit)
  xcrun -sdk "$sdk" clang++ -std=c++17 -O2 -dynamiclib -target "$target" \
    -isysroot "$(xcrun -sdk "$sdk" --show-sdk-path)" \
    -I"$ROOT/src" -I"$LLAMA/include" -I"$LLAMA/ggml/include" \
    "$ROOT/src/kadr_llm.cpp" $(find "$dir" -name '*.a' | sort) "${frameworks[@]}" \
    -install_name @rpath/KadrLlm.framework/KadrLlm -o "$fw/KadrLlm"
  cat > "$fw/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>KadrLlm</string>
  <key>CFBundleIdentifier</key><string>uz.hookkadr.KadrLlm</string>
  <key>CFBundleName</key><string>KadrLlm</string>
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

# One universal simulator framework (Xcode builds simulators for arm64 and x86_64).
SIM=$ROOT/build/ios-iphonesimulator-universal/KadrLlm.framework
rm -rf "$SIM" && mkdir -p "$SIM"
cp "$ROOT/build/ios-iphonesimulator-arm64/KadrLlm.framework/Info.plist" "$SIM/"
lipo -create "$ROOT/build/ios-iphonesimulator-arm64/KadrLlm.framework/KadrLlm" \
  "$ROOT/build/ios-iphonesimulator-x86_64/KadrLlm.framework/KadrLlm" -output "$SIM/KadrLlm"

rm -rf "$OUT/KadrLlm.xcframework" && mkdir -p "$OUT"
xcodebuild -create-xcframework \
  -framework "$ROOT/build/ios-iphoneos-arm64/KadrLlm.framework" \
  -framework "$SIM" \
  -output "$OUT/KadrLlm.xcframework" >/dev/null
echo "built $OUT/KadrLlm.xcframework"
