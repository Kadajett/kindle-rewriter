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

# ---- Ubuntu 24.04 / modern distro workarounds for cm-14.1 ----

# Java 8 is required for cm-14.1 (Android 7.1.2)
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export PATH="$JAVA_HOME/bin:$PATH"
echo "[env] Using Java: $(java -version 2>&1 | head -1)"

# Jack compiler SSL is fixed via custom curl-jack wrapper + JackHTTPClient.java
# in prebuilts/sdk/tools/ (bypasses OpenSSL 3.x by using Java's SSL directly).
# DO NOT set ANDROID_COMPILE_WITH_JACK=false — dx lacks invokedynamic support.
unset ANDROID_COMPILE_WITH_JACK
echo "[env] Jack enabled (using curl-jack SSL wrapper)"

# ccache for faster rebuilds
export USE_CCACHE=1
export CCACHE_EXEC=/usr/bin/ccache

# Python 2 is required by the AOSP build system.
# If pyenv is available and has python 2.7, activate it.
if command -v pyenv &>/dev/null; then
    eval "$(pyenv init -)"
    echo "[env] Using Python: $(python --version 2>&1)"
fi

# Prebuilt flex-2.5.39 crashes on modern glibc; ensure system flex is used.
PREBUILT_FLEX="$ARIEL_DIR/prebuilts/misc/linux-x86/flex/flex-2.5.39"
if [ -x "$PREBUILT_FLEX" ] && ! [ -L "$PREBUILT_FLEX" ]; then
    echo "[env] Replacing prebuilt flex with system flex symlink"
    mv "$PREBUILT_FLEX" "$PREBUILT_FLEX.bak"
    ln -sf /usr/bin/flex "$PREBUILT_FLEX"
fi

# FlexLexer.h in mclinker must match system flex version
MCLINKER_FLEXLEXER="$ARIEL_DIR/frameworks/compile/mclinker/include/mcld/Script/FlexLexer.h"
if [ -f /usr/include/FlexLexer.h ] && [ -f "$MCLINKER_FLEXLEXER" ]; then
    if ! cmp -s /usr/include/FlexLexer.h "$MCLINKER_FLEXLEXER"; then
        echo "[env] Updating mclinker FlexLexer.h to match system version"
        cp /usr/include/FlexLexer.h "$MCLINKER_FLEXLEXER"
    fi
fi

# Prebuilt clang needs legacy .so.5 symlinks on modern Ubuntu
for lib in libncurses libtinfo; do
    target="/usr/lib/x86_64-linux-gnu/${lib}.so.5"
    source="/usr/lib/x86_64-linux-gnu/${lib}.so.6"
    if [ ! -e "$target" ] && [ -e "$source" ]; then
        echo "[env] Creating $target -> $source symlink (needs sudo)"
        sudo ln -sf "$source" "$target"
    fi
done

# ---- End workarounds ----

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

# Step 2: Apply overlay files to source tree
echo "[1/5] Applying overlay to source tree..."
# Jack SSL fix: curl-jack wrapper + JackHTTPClient replace broken curl for Jack server comms
JACK_OVERLAY="$PROJECT_ROOT/overlay/prebuilts/sdk/tools"
if [ -d "$JACK_OVERLAY" ]; then
    cp "$JACK_OVERLAY/curl-jack" "$ARIEL_DIR/prebuilts/sdk/tools/curl-jack"
    cp "$JACK_OVERLAY/JackHTTPClient.java" "$ARIEL_DIR/prebuilts/sdk/tools/JackHTTPClient.java"
    cp "$JACK_OVERLAY/jack-admin" "$ARIEL_DIR/prebuilts/sdk/tools/jack-admin"
    chmod +x "$ARIEL_DIR/prebuilts/sdk/tools/curl-jack" "$ARIEL_DIR/prebuilts/sdk/tools/jack-admin"
    echo "[overlay] Jack SSL fix files applied"
fi

# Step 3: Set up build environment
# AOSP/LineageOS build system uses unset variables freely, so disable nounset
echo "[2/5] Setting up build environment..."
set +u
source build/envsetup.sh

# Step 4: Select build target
echo "[3/5] Selecting ariel target..."
lunch lineage_ariel-userdebug

# Step 5: Include our custom vendor config
echo "[4/5] Applying KindleRewriter customizations..."
export KINDLE_REWRITER_BUILD=true

# Step 6: Build
echo "[5/5] Building ROM (this will take 1-4 hours depending on hardware)..."
echo "Using $(nproc) cores"
echo ""

# Kill any stale Jack server so it restarts fresh with correct certs
pkill -9 -f ServerLauncher 2>/dev/null || true

# Ensure JackHTTPClient.class is compiled with Java 8
TOOLS_DIR="$ARIEL_DIR/prebuilts/sdk/tools"
if [ -f "$TOOLS_DIR/JackHTTPClient.java" ]; then
    echo "[env] Compiling JackHTTPClient.java with Java 8..."
    javac "$TOOLS_DIR/JackHTTPClient.java"
fi

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
