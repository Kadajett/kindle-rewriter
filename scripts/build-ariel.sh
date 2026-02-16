#!/usr/bin/env bash
set -euo pipefail

# Build KindleRewriter ROM for Fire HD 7 4th gen (ariel / SQ46CW)
# Based on LineageOS 14.1 (Android 7.1.2)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_ROOT="${BUILD_ROOT:-$HOME/kindle-rewriter-build}"
ARIEL_DIR="$BUILD_ROOT/ariel"

if [ ! -d "$ARIEL_DIR/build" ]; then
    echo "Error: Source tree not synced. Run sync-ariel.sh first."
    exit 1
fi

cd "$ARIEL_DIR"

echo "=== Building KindleRewriter ROM for ariel (SQ46CW) ==="
echo ""

# Step 1: Download KOReader APK if not present
KOREADER_APK="$PROJECT_ROOT/overlay/vendor/kindle-rewriter/prebuilt/KOReader.apk"
if [ ! -f "$KOREADER_APK" ]; then
    echo "[pre-build] Downloading KOReader..."
    KOREADER_VERSION="v2024.11"
    KOREADER_URL="https://github.com/koreader/koreader/releases/download/${KOREADER_VERSION}/koreader-android-arm-${KOREADER_VERSION}.apk"
    curl -L -o "$KOREADER_APK" "$KOREADER_URL"
    echo "KOReader downloaded: $KOREADER_APK"
else
    echo "[pre-build] KOReader APK already present"
fi

# Step 2: Set up build environment
echo "[1/4] Setting up build environment..."
source build/envsetup.sh

# Step 3: Select build target
echo "[2/4] Selecting ariel target..."
lunch lineage_ariel-userdebug

# Step 4: Include our custom vendor config
echo "[3/4] Applying KindleRewriter customizations..."
export KINDLE_REWRITER_BUILD=true

# Step 5: Build
echo "[4/4] Building ROM (this will take 1-4 hours depending on hardware)..."
echo "Using $(nproc) cores"
echo ""

# Build without GApps (we never include them)
mka bacon -j$(nproc)

echo ""
echo "=== Build complete! ==="
echo ""

# Find the output ZIP
OUTPUT_DIR="$ARIEL_DIR/out/target/product/ariel"
ZIP_FILE=$(ls -t "$OUTPUT_DIR"/lineage-14.1-*-ariel.zip 2>/dev/null | head -1)

if [ -n "$ZIP_FILE" ]; then
    echo "ROM ZIP: $ZIP_FILE"
    echo "Size: $(du -h "$ZIP_FILE" | cut -f1)"
    echo ""
    echo "To flash:"
    echo "  1. Boot into TWRP recovery"
    echo "  2. adb sideload $ZIP_FILE"
    echo "  3. Or: copy to SD card and flash from TWRP"
    echo ""
    echo "See docs/flashing-guide.md for full instructions."
else
    echo "Warning: Could not find output ZIP. Check build output above for errors."
fi
