# Build Guide: Fire HD 7 4th Gen (SQ46CW / "ariel")

## Device Specs

- **SoC:** MediaTek MT8135 (ARMv7, dual Cortex-A15 + dual Cortex-A7)
- **RAM:** 1GB
- **Storage:** 8/16GB
- **Display:** 1280x800 IPS LCD
- **WiFi:** 802.11 a/b/g/n dual-band
- **Base ROM:** LineageOS 14.1 (Android 7.1.2)

## Prerequisites

- Ubuntu 18.04+ (or 20.04 in a Docker container)
- 350GB+ free disk space
- 16GB+ RAM recommended
- A working ariel tablet for testing
- USB cable
- 1.8v Serial-to-USB adapter (for recovery/debugging, optional)

## Step 1: Unlock the Bootloader

The ariel uses Amazon's locked bootloader. The **amonet** exploit unlocks it.

### Using amonet

```bash
git clone https://github.com/R0rt1z2/amonet.git -b mt8135-ariel
cd amonet

# Put the tablet into download mode:
# 1. Power off completely
# 2. Hold Volume Down + Power until the screen goes black
# 3. Release Power, keep holding Volume Down
# 4. Connect USB cable

python3 main.py
```

This exploits the GCPU cryptographic processor to bypass signature verification. After running, the bootloader will be unlocked and you can flash custom recovery.

**Reference:** https://blog.r0rt1z2.com/posts/hacking-2014-tablet/

## Step 2: Flash TWRP Recovery

After bootloader unlock:

```bash
# Download TWRP for ariel
# Check https://xdaforums.com/t/unlock-root-twrp-unbrick-fire-hd7-hd6-ariel.4679761/
# for the latest TWRP image

fastboot flash recovery twrp-ariel.img
fastboot reboot recovery
```

## Step 3: Set Up Build Environment

```bash
cd kindleRewriter/scripts
chmod +x *.sh
./setup-build-env.sh
```

## Step 4: Sync Source Tree

```bash
./sync-ariel.sh
```

This downloads ~30GB of LineageOS 14.1 source code plus the ariel device tree, kernel, and vendor blobs.

### Device tree repos

| Repo | Path | Description |
|------|------|-------------|
| amazon-oss/android_device_amazon_ariel | device/amazon/ariel | Device-specific config |
| amazon-oss/android_device_amazon_mt8135-common | device/amazon/mt8135-common | MT8135 common HAL |
| amazon-oss/android_kernel_amazon_mt8135 | kernel/amazon/mt8135 | Kernel source |
| amazon-oss/proprietary_vendor_amazon | vendor/amazon | Proprietary blobs |

## Step 5: Build the ROM

```bash
./build-ariel.sh
```

The build script:
1. Downloads KOReader APK (if not already present)
2. Sets up the build environment
3. Selects the ariel target
4. Applies KindleRewriter customizations (strips bloat, adds our apps)
5. Builds the full ROM ZIP

Output: `out/target/product/ariel/lineage-14.1-*-ariel.zip`

## Step 6: Flash the ROM

See [flashing-guide.md](flashing-guide.md) for detailed per-tablet flashing instructions.

## Troubleshooting

### Build fails with missing vendor blobs

The `amazon-oss` repos may not have all required proprietary blobs. If you hit missing blob errors:

1. Extract blobs from a stock FireOS 5 firmware:
   ```bash
   # From a running stock tablet:
   adb pull /system vendor/amazon/ariel/proprietary/
   ```
2. Or find the stock firmware and extract from the system.img

### amonet fails to connect

- Ensure you're using a data-capable USB cable (not charge-only)
- Try a USB 2.0 port (USB 3.0 can cause issues with MediaTek download mode)
- On Linux, you may need udev rules for MediaTek devices:
  ```bash
  echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="0e8d", MODE="0666"' | sudo tee /etc/udev/rules.d/51-mediatek.rules
  sudo udevadm control --reload-rules
  ```

### Build runs out of memory

- Reduce parallel jobs: edit build-ariel.sh, change `-j$(nproc)` to `-j4` or `-j2`
- Add swap: `sudo fallocate -l 8G /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile`
