#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/build/output"
APP_NAME="lemonade-controller"

if command -v fastforge >/dev/null 2>&1; then
    DIST_CMD="fastforge"
elif command -v flutter_distributor >/dev/null 2>&1; then
    DIST_CMD="flutter_distributor"
else
    echo "[x] Neither fastforge nor flutter_distributor was found in PATH"
    exit 1
fi

VERSION_LINE=$(grep -E "^version:" "$ROOT_DIR/pubspec.yaml" | head -n 1 || true)
if [ -z "$VERSION_LINE" ]; then
    echo "[x] Could not read version from pubspec.yaml"
    exit 1
fi

RAW_VERSION=$(echo "$VERSION_LINE" | sed 's/version:[[:space:]]*//')
APP_VERSION=$(echo "$RAW_VERSION" | cut -d'+' -f1)
BUILD_NUMBER=$(echo "$RAW_VERSION" | cut -s -d'+' -f2)
if [ -z "${BUILD_NUMBER:-}" ]; then
    BUILD_NUMBER="0"
fi

# mkdir -p "$OUTPUT_DIR"

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

echo " [2/2] Copying package to output..."
echo " --------------------------------------------"

DEB_FILE="$(find "$ROOT_DIR/build/dist" -type f -name '*.deb' | sort | tail -n 1 || true)"

if [ -z "$DEB_FILE" ]; then
    echo " [x] No .deb file found under $ROOT_DIR/build/dist"
    exit 1
fi

FINAL_NAME="$APP_NAME-$APP_VERSION-linux-$ARCH.deb"
cp -f "$DEB_FILE" "$OUTPUT_DIR/$FINAL_NAME"

echo " [ok]  Source: $(basename "$DEB_FILE")"
echo " [ok]  Output: $FINAL_NAME"
echo ""
echo "  Install:"
echo "    sudo apt install ./$OUTPUT_DIR/$FINAL_NAME"
echo ""