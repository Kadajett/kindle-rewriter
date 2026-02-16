#!/usr/bin/env bash
set -euo pipefail

# Sync LineageOS source and ariel device tree for Fire HD 7 4th gen (SQ46CW)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_ROOT="${BUILD_ROOT:-$HOME/kindle-rewriter-build}"
ARIEL_DIR="$BUILD_ROOT/ariel"

if [ ! -d "$ARIEL_DIR/.repo" ]; then
    echo "Error: Run setup-build-env.sh first"
    exit 1
fi

cd "$ARIEL_DIR"

# Create local manifests BEFORE syncing so repo picks up the correct repos
echo "=== Setting up local manifests ==="
mkdir -p .repo/local_manifests

cat > .repo/local_manifests/ariel.xml << 'MANIFEST'
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
    <!-- Device tree for Fire HD 7 4th gen (ariel) -->
    <project name="amazon-oss/android_device_amazon_ariel"
             path="device/amazon/ariel"
             remote="github"
             revision="cm-14.1" />

    <!-- Common MT8135 device config -->
    <project name="amazon-oss/android_device_amazon_mt8135-common"
             path="device/amazon/mt8135-common"
             remote="github"
             revision="cm-14.1" />

    <!-- Kernel -->
    <project name="amazon-oss/android_kernel_amazon_mt8135"
             path="kernel/amazon/mt8135"
             remote="github"
             revision="cm-14.1" />

    <!-- Vendor blobs (device-specific) -->
    <project name="amazon-oss/android_vendor_amazon_ariel"
             path="vendor/amazon/ariel"
             remote="github"
             revision="cm-14.1" />

    <!-- Vendor blobs (common MT8135) -->
    <project name="amazon-oss/android_vendor_amazon_mt8135-common"
             path="vendor/amazon/mt8135-common"
             remote="github"
             revision="cm-14.1" />

    <!-- MediaTek MT76xx WiFi HAL (provides libwifi-hal-mt66xx) -->
    <project name="amazon-oss/android_hardware_mediatek_mt76xx"
             path="hardware/mediatek/mt76xx"
             remote="github"
             revision="cm-14.1" />
</manifest>
MANIFEST

echo "=== Syncing LineageOS 14.1 source tree + device repos ==="
echo "This will download ~30GB on first run. Go get coffee."
echo ""

# Sync everything (main tree + device repos from local manifest)
repo sync -j$(nproc) -c --no-clone-bundle --no-tags --force-sync

# Link our overlay into the build tree
echo ""
echo "=== Linking KindleRewriter overlay ==="
ln -sfn "$PROJECT_ROOT/overlay/vendor/kindle-rewriter" "$ARIEL_DIR/vendor/kindle-rewriter"
ln -sfn "$PROJECT_ROOT/overlay/packages/apps/KidsLauncher" "$ARIEL_DIR/packages/apps/KidsLauncher"

echo ""
echo "=== Sync complete for ariel ==="
echo "Next: run ./build-ariel.sh"
