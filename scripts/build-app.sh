#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CONFIG=${CONFIGURATION:-release}
ARCH=$(uname -m)
APP="$ROOT/build/NotchChat.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
FRAMEWORKS="$CONTENTS/Frameworks"
RESOURCES="$CONTENTS/Resources"

read_env_value() {
  awk -v key="$1" '
    index($0, key "=") == 1 { value = substr($0, length(key) + 2) }
    END {
      sub(/\r$/, "", value)
      if ((substr(value, 1, 1) == "\"") && (substr(value, length(value), 1) == "\"")) {
        value = substr(value, 2, length(value) - 2)
      }
      print value
    }
  ' "$ROOT/.env"
}

TG_APIID_VALUE=${TG_APIID:-}
TG_APIHASH_VALUE=${TG_APIHASH:-}
if [ -f "$ROOT/.env" ]; then
  [ -n "$TG_APIID_VALUE" ] || TG_APIID_VALUE=$(read_env_value TG_APIID)
  [ -n "$TG_APIHASH_VALUE" ] || TG_APIHASH_VALUE=$(read_env_value TG_APIHASH)
fi

if [ -n "$TG_APIID_VALUE" ] || [ -n "$TG_APIHASH_VALUE" ]; then
  case "$TG_APIID_VALUE" in
    ''|*[!0-9]*) echo "TG_APIID must contain digits only." >&2; exit 1 ;;
  esac
  case "$TG_APIHASH_VALUE" in
    ''|*[!0-9a-fA-F]*|???????????????????????????????|?????????????????????????????????*)
      echo "TG_APIHASH must contain exactly 32 hexadecimal characters." >&2
      exit 1
      ;;
  esac
fi

cd "$ROOT"
mkdir -p "$ROOT/.build/cache" "$ROOT/.build/clang-cache"
export CLANG_MODULE_CACHE_PATH="$ROOT/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$ROOT/.build/clang-cache"
swift build -c "$CONFIG" --disable-sandbox --cache-path "$ROOT/.build/cache"
BIN_DIR=$(swift build -c "$CONFIG" --disable-sandbox --cache-path "$ROOT/.build/cache" --show-bin-path)

TDJSON=$(sh "$ROOT/scripts/build-tdlib.sh" | tail -n 1)

mkdir -p "$MACOS" "$FRAMEWORKS" "$RESOURCES"
chmod -R u+w "$APP" 2>/dev/null || true
cp "$BIN_DIR/NotchChat" "$MACOS/NotchChat"
cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"
cp "$ROOT/Resources/MenuBarIcon.png" "$RESOURCES/MenuBarIcon.png"
xcrun actool "$ROOT/Resources/Assets.xcassets" \
  --compile "$RESOURCES" \
  --platform macosx \
  --minimum-deployment-target 14.0 \
  --app-icon AppIcon \
  --output-partial-info-plist "$ROOT/.build/AppIcon-Info.plist"
if [ -n "$TG_APIID_VALUE" ]; then
  /usr/libexec/PlistBuddy -c "Add :TelegramAPIID string $TG_APIID_VALUE" "$CONTENTS/Info.plist"
  /usr/libexec/PlistBuddy -c "Add :TelegramAPIHash string $TG_APIHASH_VALUE" "$CONTENTS/Info.plist"
fi
cp "$TDJSON" "$FRAMEWORKS/libtdjson.dylib"

for LIB in libssl.3.dylib libcrypto.3.dylib; do
  SOURCE_LIB="/opt/homebrew/opt/openssl@3/lib/$LIB"
  if [ -f "$SOURCE_LIB" ]; then
    cp "$SOURCE_LIB" "$FRAMEWORKS/$LIB"
    install_name_tool -id "@loader_path/$LIB" "$FRAMEWORKS/$LIB"
  fi
done

install_name_tool \
  -change /opt/homebrew/opt/openssl@3/lib/libssl.3.dylib @loader_path/libssl.3.dylib \
  -change /opt/homebrew/opt/openssl@3/lib/libcrypto.3.dylib @loader_path/libcrypto.3.dylib \
  "$FRAMEWORKS/libtdjson.dylib" 2>/dev/null || true
install_name_tool \
  -change /opt/homebrew/opt/openssl@3/lib/libcrypto.3.dylib @loader_path/libcrypto.3.dylib \
  "$FRAMEWORKS/libssl.3.dylib" 2>/dev/null || true

# Homebrew bottles can record a versioned Cellar path instead of the stable opt path.
SSL_CRYPTO_DEP=$(otool -L "$FRAMEWORKS/libssl.3.dylib" | awk '/libcrypto\.3\.dylib/ { print $1; exit }')
if [ -n "$SSL_CRYPTO_DEP" ] && [ "$SSL_CRYPTO_DEP" != "@loader_path/libcrypto.3.dylib" ]; then
  install_name_tool \
    -change "$SSL_CRYPTO_DEP" @loader_path/libcrypto.3.dylib \
    "$FRAMEWORKS/libssl.3.dylib"
fi

codesign --force --sign - "$FRAMEWORKS/libcrypto.3.dylib"
codesign --force --sign - "$FRAMEWORKS/libssl.3.dylib"
codesign --force --sign - "$FRAMEWORKS/libtdjson.dylib"
codesign --force --sign - "$APP"

echo "$APP"

