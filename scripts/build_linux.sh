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
echo "  Lemonade Controller - Linux Build"
echo "  Version: $APP_VERSION (+$BUILD_NUMBER)"
echo "  Arch:    $ARCH"
echo " ============================================"
echo ""

echo " [1/4] Building Flutter app..."
echo " --------------------------------------------"
(
    cd "$ROOT_DIR"
    flutter build linux --release
)
echo " [ok]  Flutter build complete."
echo ""

echo " [2/4] Updating installed_size in deb config..."
echo " --------------------------------------------"
INSTALLED_SIZE="$(du -sk "$ROOT_DIR/build/linux/x64/release/bundle" | cut -f1)"
DEB_CONFIG="$ROOT_DIR/linux/packaging/deb/make_config.yaml"
if [ -z "$INSTALLED_SIZE" ]; then
    echo " [x] Could not calculate installed size"
    exit 1
fi
sed -i "s/^installed_size:.*/installed_size: $INSTALLED_SIZE/" "$DEB_CONFIG"
echo " [ok]  installed_size: $INSTALLED_SIZE"
echo ""

echo " [3/4] Packaging Debian package..."
echo " --------------------------------------------"
(
    cd "$ROOT_DIR"
    "$DIST_CMD" package --platform linux --targets deb
)
echo " [ok]  DEB packaging complete."
echo ""

echo " [4/4] Packaging RPM package..."
echo " --------------------------------------------"
(
    cd "$ROOT_DIR"
    "$DIST_CMD" package --platform linux --targets rpm
)
echo " [ok]  RPM packaging complete."
echo ""

echo " Copying packages to release folder..."
echo " --------------------------------------------"
mkdir -p "$OUTPUT_DIR"

DEB_FILE="$(find "$ROOT_DIR/build/dist" -type f -name '*.deb' | sort | tail -n 1 || true)"
RPM_FILE="$(find "$ROOT_DIR/build/dist" -type f -name '*.rpm' | sort | tail -n 1 || true)"

COPIED=0

if [ -n "$DEB_FILE" ]; then
    FINAL_DEB="$APP_NAME-$VERSION_TAG-linux-$ARCH.deb"
    cp -f "$DEB_FILE" "$OUTPUT_DIR/$FINAL_DEB"
    echo " [ok]  $FINAL_DEB"
    COPIED=$((COPIED + 1))
else
    echo " [!]  No .deb file found under $ROOT_DIR/build/dist"
fi

if [ -n "$RPM_FILE" ]; then
    FINAL_RPM="$APP_NAME-$VERSION_TAG-linux-$ARCH.rpm"
    cp -f "$RPM_FILE" "$OUTPUT_DIR/$FINAL_RPM"
    echo " [ok]  $FINAL_RPM"
    COPIED=$((COPIED + 1))
else
    echo " [!]  No .rpm file found under $ROOT_DIR/build/dist"
fi

echo ""
echo " ============================================"
echo "  Build complete! $COPIED package(s) output."
echo ""
echo "  Output:"
for f in "$OUTPUT_DIR/$APP_NAME"-*-linux-*; do
    [ -e "$f" ] && echo "    $(basename "$f")"
done
echo ""
echo "  Install (Debian/Ubuntu):"
echo "    sudo apt install ./$OUTPUT_DIR/$FINAL_DEB"
echo ""
echo "  Install (Fedora/RHEL):"
echo "    sudo dnf install ./$OUTPUT_DIR/$FINAL_RPM"
echo " ============================================"
echo ""
