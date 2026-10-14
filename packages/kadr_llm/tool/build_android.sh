#!/usr/bin/env bash
# Builds libkadr_llm.so for Android arm64 from the pinned llama.cpp checkout
# and src/kadr_llm.cpp, into android/src/main/jniLibs.
#
#   tool/fetch_llama.sh && tool/build_android.sh
#
# Two CPU builds ship side by side and Dart picks one at runtime:
#   libkadr_llm.so         armv8.2-a + dotprod + fp16 (phones from ~2018 on)
#   libkadr_llm_compat.so  plain armv8-a, for older cores (no SIGILL)
# Only kadr_* is exported; ggml and libc++ stay private, so this library never
# clashes with the ggml copy inside libkadr_sd.so.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$(pwd)
LLAMA=$ROOT/third_party/llama.cpp
OUT=$ROOT/android/src/main/jniLibs/arm64-v8a
API=30

[ -d "$LLAMA" ] || { echo "run tool/fetch_llama.sh first"; exit 1; }
SDK=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$(flutter config --machine 2>/dev/null | sed -n 's/.*"android-sdk": *"\([^"]*\)".*/\1/p')}}
[ -n "$SDK" ] || SDK=/opt/homebrew/share/android-commandlinetools
NDK=${ANDROID_NDK_HOME:-$(ls -d "$SDK"/ndk/* 2>/dev/null | sort -V | tail -1)}
[ -f "$NDK/build/cmake/android.toolchain.cmake" ] || { echo "Android NDK not found (set ANDROID_NDK_HOME)"; exit 1; }
CXX=$(ls "$NDK"/toolchains/llvm/prebuilt/*/bin/aarch64-linux-android$API-clang++ | head -1)
STRIP=$(ls "$NDK"/toolchains/llvm/prebuilt/*/bin/llvm-strip | head -1)

mkdir -p "$ROOT/build" "$OUT"
VERSION_SCRIPT=$ROOT/build/android_exports.map
{ echo '{ global:'; grep -o 'kadr_[a-z_]*(' "$ROOT/src/kadr_llm.h" | sort -u | sed 's/($/;/'; echo 'local: *; };'; } > "$VERSION_SCRIPT"

build_variant() {
  local name=$1 arch=$2
  local dir=$ROOT/build/android-$name
  cmake -S "$LLAMA" -B "$dir" -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$NDK/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-$API -DANDROID_STL=c++_static \
    -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DGGML_NATIVE=OFF -DGGML_CPU_ARM_ARCH="$arch" -DGGML_OPENMP=OFF -DGGML_LLAMAFILE=ON \
    -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF -DLLAMA_BUILD_SERVER=OFF \
    -DLLAMA_BUILD_TOOLS=OFF -DLLAMA_CURL=OFF >/dev/null
  cmake --build "$dir" --target llama >/dev/null

  "$CXX" -std=c++17 -O2 -shared -fPIC -static-libstdc++ -march="$arch" \
    -I"$ROOT/src" -I"$LLAMA/include" -I"$LLAMA/ggml/include" \
    "$ROOT/src/kadr_llm.cpp" \
    -Wl,--start-group $(find "$dir" -name '*.a' | sort) -Wl,--end-group \
    -Wl,--version-script="$VERSION_SCRIPT" -Wl,--exclude-libs,ALL -Wl,--gc-sections \
    -Wl,-z,max-page-size=16384 -Wl,-soname,"$name.so" -llog -lm -ldl \
    -o "$OUT/$name.so"
  "$STRIP" --strip-unneeded "$OUT/$name.so"
  echo "$name.so ($arch): $(du -h "$OUT/$name.so" | cut -f1)"
}

build_variant libkadr_llm armv8.2-a+dotprod+fp16
build_variant libkadr_llm_compat armv8-a
