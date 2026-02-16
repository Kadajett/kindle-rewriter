#!/usr/bin/env bash
set -euo pipefail

# Install udev rules for automatic Fire tablet detection
# This allows the batch-flash tool to detect tablets without running as root
# and optionally triggers processing automatically on USB plug-in

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RULES_FILE="/etc/udev/rules.d/99-kindle-rewriter.rules"

echo "=== Installing KindleRewriter udev rules ==="
echo ""

# Create the rules file
sudo tee "$RULES_FILE" > /dev/null << 'RULES'
# KindleRewriter: udev rules for Amazon Fire tablets

# Amazon Fire tablets in ADB mode (normal boot / recovery)
SUBSYSTEM=="usb", ATTR{idVendor}=="1949", MODE="0666", GROUP="plugdev"

# MediaTek devices in download mode (for amonet exploit on ariel)
SUBSYSTEM=="usb", ATTR{idVendor}=="0e8d", MODE="0666", GROUP="plugdev"

# MediaTek devices in fastboot mode
SUBSYSTEM=="usb", ATTR{idVendor}=="0e8d", ATTR{idProduct}=="0003", MODE="0666", GROUP="plugdev"

# Amazon devices in fastboot mode
SUBSYSTEM=="usb", ATTR{idVendor}=="1949", ATTR{idProduct}=="0fff", MODE="0666", GROUP="plugdev"

# Texas Instruments OMAP (for soho in certain modes)
SUBSYSTEM=="usb", ATTR{idVendor}=="0451", MODE="0666", GROUP="plugdev"
RULES

# Reload udev rules
sudo udevadm control --reload-rules
sudo udevadm trigger

# Ensure the user is in the plugdev group
if ! groups | grep -q plugdev; then
    sudo usermod -aG plugdev "$USER"
    echo "Added $USER to plugdev group. You may need to log out and back in."
fi

echo ""
echo "udev rules installed at: $RULES_FILE"
echo ""
echo "All Fire tablets will now be accessible without root."
echo "Run 'batch-flash.sh --watch' to start auto-processing."
