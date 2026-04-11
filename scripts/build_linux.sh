#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/dist"
APP_NAME="lemonade-controller"

if command -v fastforge >/dev/null 2>&1; then
    DIST_CMD="fastforge"
elif command -v flutter_distributor >/dev/null 2>&1; then
    DIST_CMD="flutter_distributor"
else
    echo "[x] Neither fastforge nor flutter_distributor was found in PATH"
    echo "    Install with: dart pub global activate fastforge"
    exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
    echo "[x] Flutter not found in PATH"
    exit 1
fi

VERSION_LINE="$(grep -E '^version:' "$ROOT_DIR/pubspec.yaml" | head -n 1 || true)"
if [ -z "$VERSION_LINE" ]; then
    echo "[x] Could not read version from pubspec.yaml"
    exit 1
fi

RAW_VERSION="$(echo "$VERSION_LINE" | sed 's/version:[[:space:]]*//')"
APP_VERSION="$(echo "$RAW_VERSION" | cut -d'+' -f1)"
BUILD_NUMBER="$(echo "$RAW_VERSION" | cut -s -d'+' -f2)"
if [ -z "${BUILD_NUMBER:-}" ]; then
    BUILD_NUMBER="0"
fi

VERSION_TAG="$APP_VERSION"
ARCH="$(dpkg --print-architecture 2>/dev/null || uname -m)"

echo ""
echo " ============================================"
echo "  Lemonade Controller - Linux DEB Build"
echo "  Version: $APP_VERSION (+$BUILD_NUMBER)"
echo "  Arch:    $ARCH"
echo " ============================================"
echo ""

echo " [1/2] Packaging Debian package..."
echo " --------------------------------------------"
(
    cd "$ROOT_DIR"
    "$DIST_CMD" release --name release
)
echo " [ok]  Packaging complete."
echo ""

echo " [2/2] Copying package to release folder..."
echo " --------------------------------------------"

DEB_FILE="$(find "$ROOT_DIR/build/dist" -type f -name '*.deb' | sort | tail -n 1 || true)"

if [ -z "$DEB_FILE" ]; then
    echo " [x] No .deb file found under $ROOT_DIR/build/dist"
    echo "     Found these instead:"
    find "$ROOT_DIR/build" -type f -name '*.deb' || true
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

FINAL_NAME="$APP_NAME-$VERSION_TAG-linux-$ARCH.deb"
cp -f "$DEB_FILE" "$OUTPUT_DIR/$FINAL_NAME"

echo " [ok]  Source: $(basename "$DEB_FILE")"
echo " [ok]  Output: $FINAL_NAME"
echo ""

echo " ============================================"
echo "  Build complete!"
echo ""
echo "  Output:"
echo "    $OUTPUT_DIR/$FINAL_NAME"
echo ""
echo "  Install:"
echo "    sudo apt install ./$OUTPUT_DIR/$FINAL_NAME"
echo " ============================================"
echo ""