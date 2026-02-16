#!/usr/bin/env bash
set -euo pipefail

# Sync LineageOS source and soho device tree for Kindle Fire HD 7 3rd gen (P48WVB4)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_ROOT="${BUILD_ROOT:-$HOME/kindle-rewriter-build}"
SOHO_DIR="$BUILD_ROOT/soho"

if [ ! -d "$SOHO_DIR/.repo" ]; then
    echo "Error: Run setup-build-env.sh first"
    exit 1
fi

cd "$SOHO_DIR"

echo "=== Syncing LineageOS 11.0 source tree ==="
echo "This will download ~20GB. Go get more coffee."
echo ""

repo sync -j$(nproc) -c --no-clone-bundle --no-tags --force-sync

echo ""
echo "=== Adding soho device tree and kernel ==="

# The soho (OMAP4470) shares the omap4-common tree with the "tate" (earlier Fire HD)
# We need to adapt it. The tate tree is officially in LineageOS.
mkdir -p .repo/local_manifests

cat > .repo/local_manifests/soho.xml << 'MANIFEST'
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
    <!-- OMAP4 common device config (from LineageOS, supports tate/jem) -->
    <project name="LineageOS/android_device_amazon_omap4-common"
             path="device/amazon/omap4-common"
             remote="github"
             revision="cm-11.0" />

    <!-- Tate device tree (closest relative to soho, same OMAP4 SoC family) -->
    <!-- We'll fork/adapt this for soho -->
    <project name="LineageOS/android_device_amazon_tate"
             path="device/amazon/tate"
             remote="github"
             revision="cm-11.0" />

    <!-- OMAP4 kernel -->
    <project name="LineageOS/android_kernel_amazon_omap4-common"
             path="kernel/amazon/omap4-common"
             remote="github"
             revision="cm-11.0" />

    <!-- Vendor blobs -->
    <project name="AntaresOne/proprietary_vendor_amazon"
             path="vendor/amazon"
             remote="github"
             revision="cm-11.0" />
</manifest>
MANIFEST

echo "Local manifest created. Syncing device repos..."
repo sync -j$(nproc) -c --no-clone-bundle --no-tags --force-sync \
    device/amazon/omap4-common \
    device/amazon/tate \
    kernel/amazon/omap4-common \
    vendor/amazon

# We need to create a soho device tree based on tate
# This will be done in the build script or manually
echo ""
echo "=== IMPORTANT: Soho device tree adaptation needed ==="
echo "The soho (P48WVB4) uses OMAP4470, same family as tate (OMAP4460)."
echo "We need to create device/amazon/soho by adapting the tate tree."
echo "Key differences: display resolution (800x1280 vs 1280x800),"
echo "different sensor configs, and updated firmware blobs."
echo "See docs/soho-build-guide.md for details."
echo ""

# Link our overlay
echo "=== Linking KindleRewriter overlay ==="
ln -sfn "$PROJECT_ROOT/overlay/vendor/kindle-rewriter" "$SOHO_DIR/vendor/kindle-rewriter"
ln -sfn "$PROJECT_ROOT/overlay/packages/apps/KidsLauncher" "$SOHO_DIR/packages/apps/KidsLauncher"

echo ""
echo "=== Sync complete for soho ==="
echo "Next: adapt the device tree, then run ./build-soho.sh"
