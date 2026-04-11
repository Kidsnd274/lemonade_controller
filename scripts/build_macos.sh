#!/bin/bash
set -e

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/dist"
APP_NAME="lemonade-controller"
APP_BUNDLE="Lemonade Controller.app"
RELEASE_DIR="$ROOT_DIR/build/macos/Build/Products/Release"

if ! command -v flutter &> /dev/null; then
    echo "[x] Flutter not found in PATH"
    exit 1
fi

VERSION_LINE=$(grep -E "^version:" "$ROOT_DIR/pubspec.yaml" | head -n 1)
if [ -z "$VERSION_LINE" ]; then
    echo "[x] Could not read version from pubspec.yaml"
    exit 1
fi

APP_VERSION=$(echo "$VERSION_LINE" | sed 's/version:[[:space:]]*//' | cut -d'+' -f1)
BUILD_NUMBER=$(echo "$VERSION_LINE" | sed 's/version:[[:space:]]*//' | cut -d'+' -f2)
if [ -z "$BUILD_NUMBER" ]; then
    BUILD_NUMBER="0"
fi

VERSION_TAG="$APP_VERSION"

echo ""
echo " ============================================"
echo "  Lemonade Controller - macOS Build"
echo "  Version: $APP_VERSION (+$BUILD_NUMBER)"
echo " ============================================"
echo ""

mkdir -p "$OUTPUT_DIR"

build_and_zip() {
    local arch_label="$1"
    local zip_arch="$2"
    local flutter_xcode_archs="$3"
    local step="$4"

    echo " [$step] Building macOS app ($arch_label)..."
    echo " --------------------------------------------"

    if [ -n "$flutter_xcode_archs" ]; then
        FLUTTER_XCODE_ARCHS="$flutter_xcode_archs" flutter build macos --release
    else
        flutter build macos --release
    fi

    if [ ! -d "$RELEASE_DIR/$APP_BUNDLE" ]; then
        echo " [x] App bundle not found at: $RELEASE_DIR/$APP_BUNDLE"
        exit 1
    fi

    local zip_name="$APP_NAME-$VERSION_TAG-macos-$zip_arch.zip"
    ditto -c -k --sequesterRsrc --keepParent "$RELEASE_DIR/$APP_BUNDLE" "$OUTPUT_DIR/$zip_name"
    echo " [ok]  $zip_name"
    echo ""
}

build_and_zip "Apple Silicon" "arm64" "arm64" "1/3"
build_and_zip "Intel" "x64" "x86_64" "2/3"
build_and_zip "Universal" "universal" "" "3/3"

echo " ============================================"
echo "  Build complete! 3 zip(s) output."
echo ""
echo "  Output:"
for f in "$OUTPUT_DIR/$APP_NAME"-*-macos-*.zip; do
    echo "    $(basename "$f")"
done
echo " ============================================"
echo ""
