#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SOURCE="$ROOT/vendor/nchat/lib/tgchat/ext/td"
BUILD="$ROOT/.build/tdlib"

if ! command -v cmake >/dev/null 2>&1; then
  echo "CMake is required. Install it with: brew install cmake" >&2
  exit 1
fi

if [ ! -f "$BUILD/CMakeCache.txt" ]; then
  cmake -S "$SOURCE" -B "$BUILD" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
    -DOPENSSL_ROOT_DIR=/opt/homebrew/opt/openssl@3 \
    -DTD_ENABLE_JNI=OFF \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5
fi

cmake --build "$BUILD" --target tdjson --parallel "${TDLIB_JOBS:-4}"
test -f "$BUILD/libtdjson.dylib"
echo "$BUILD/libtdjson.dylib"

