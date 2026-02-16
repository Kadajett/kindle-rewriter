#!/usr/bin/env bash
set -euo pipefail

# Build KindleRewriter ROM for Kindle Fire HD 7 3rd gen (soho / P48WVB4)
# Based on LineageOS 11.0 (Android 4.4)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_ROOT="${BUILD_ROOT:-$HOME/kindle-rewriter-build}"
SOHO_DIR="$BUILD_ROOT/soho"

if [ ! -d "$SOHO_DIR/build" ]; then
    echo "Error: Source tree not synced. Run sync-soho.sh first."
    exit 1
fi

cd "$SOHO_DIR"

echo "=== Building KindleRewriter ROM for soho (P48WVB4) ==="
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

# Step 2: Verify soho device tree exists
if [ ! -d "device/amazon/soho" ]; then
    echo ""
    echo "ERROR: device/amazon/soho does not exist."
    echo ""
    echo "You need to create the soho device tree by adapting the tate tree."
    echo "Quick start:"
    echo "  cp -r device/amazon/tate device/amazon/soho"
    echo "  Then edit device/amazon/soho/BoardConfig.mk for OMAP4470 specifics"
    echo "  See docs/soho-build-guide.md for full instructions."
    exit 1
fi

# Step 3: Set up build environment
echo "[1/4] Setting up build environment..."
source build/envsetup.sh

# Step 4: Select build target
echo "[2/4] Selecting soho target..."
lunch lineage_soho-userdebug

# Step 5: Include our custom vendor config
echo "[3/4] Applying KindleRewriter customizations..."
export KINDLE_REWRITER_BUILD=true

# Step 6: Build
echo "[4/4] Building ROM (this will take 1-4 hours depending on hardware)..."
echo "Using $(nproc) cores"
echo ""

mka bacon -j$(nproc)

echo ""
echo "=== Build complete! ==="
echo ""

OUTPUT_DIR="$SOHO_DIR/out/target/product/soho"
ZIP_FILE=$(ls -t "$OUTPUT_DIR"/lineage-11.0-*-soho.zip 2>/dev/null | head -1)

if [ -n "$ZIP_FILE" ]; then
    echo "ROM ZIP: $ZIP_FILE"
    echo "Size: $(du -h "$ZIP_FILE" | cut -f1)"
    echo ""
    echo "To flash:"
    echo "  1. Boot into TWRP/CM recovery"
    echo "  2. adb sideload $ZIP_FILE"
    echo "  3. Or: copy to SD card and flash from recovery"
    echo ""
    echo "See docs/flashing-guide.md for full instructions."
else
    echo "Warning: Could not find output ZIP. Check build output above for errors."
fi
