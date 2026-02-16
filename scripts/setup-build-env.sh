#!/usr/bin/env bash
set -euo pipefail

# KindleRewriter: Set up the Android/LineageOS build environment
# Run this once on a fresh Ubuntu 18.04+ machine (or in a Docker container)
# Requires ~350GB free disk space for a full source tree + build artifacts

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_ROOT="${BUILD_ROOT:-$HOME/kindle-rewriter-build}"

echo "=== KindleRewriter Build Environment Setup ==="
echo "Build root: $BUILD_ROOT"
echo ""

# ---- Step 1: Install system dependencies ----
echo "[1/5] Installing system packages..."
sudo apt-get update
sudo apt-get install -y \
    bc bison build-essential ccache curl flex g++-multilib gcc-multilib \
    git gnupg gperf imagemagick lib32ncurses-dev lib32readline-dev \
    lib32z1-dev liblz4-tool libncurses6 libncurses-dev libsdl1.2-dev \
    libssl-dev libxml2 libxml2-utils lzop pngcrush rsync schedtool \
    squashfs-tools xsltproc zip zlib1g-dev python3 python3-pip \
    openjdk-11-jdk adb fastboot repo

# ---- Step 2: Set up ccache for faster rebuilds ----
echo "[2/5] Configuring ccache..."
ccache -M 50G
echo 'export USE_CCACHE=1' >> ~/.bashrc
echo 'export CCACHE_EXEC=/usr/bin/ccache' >> ~/.bashrc

# ---- Step 3: Create build directory structure ----
echo "[3/5] Creating build directories..."
mkdir -p "$BUILD_ROOT"/{ariel,soho}

# ---- Step 4: Initialize repo for ariel (LineageOS 14.1 / Android 7.1.2) ----
echo "[4/5] Initializing LineageOS 14.1 source for ariel..."
cd "$BUILD_ROOT/ariel"
if [ ! -d ".repo" ]; then
    repo init -u https://github.com/LineageOS/android.git -b cm-14.1 --depth=1
    echo "Repo initialized for ariel (cm-14.1)"
else
    echo "Repo already initialized for ariel, skipping"
fi

# ---- Step 5: Initialize repo for soho (LineageOS 11.0 / Android 4.4) ----
echo "[5/5] Initializing LineageOS 11.0 source for soho..."
cd "$BUILD_ROOT/soho"
if [ ! -d ".repo" ]; then
    repo init -u https://github.com/LineageOS/android.git -b cm-11.0 --depth=1
    echo "Repo initialized for soho (cm-11.0)"
else
    echo "Repo already initialized for soho, skipping"
fi

echo ""
echo "=== Setup complete ==="
echo ""
echo "Next steps:"
echo "  1. Run: ./sync-ariel.sh    (downloads ~30GB of source)"
echo "  2. Run: ./sync-soho.sh     (downloads ~20GB of source)"
echo "  3. Add device trees (see docs/ariel-build-guide.md)"
echo "  4. Run: ./build-ariel.sh   (builds the ROM)"
echo "  5. Run: ./build-soho.sh    (builds the ROM)"
echo ""
echo "Build root: $BUILD_ROOT"
