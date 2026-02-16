# Build Guide: Kindle Fire HD 7 3rd Gen (P48WVB4 / "soho")

## Device Specs

- **SoC:** Texas Instruments OMAP 4470 (ARMv7, dual Cortex-A9 @ 1.5GHz)
- **GPU:** PowerVR SGX544
- **RAM:** 1GB
- **Storage:** 8/16GB
- **Display:** 1280x800 IPS LCD
- **WiFi:** 802.11 a/b/g/n dual-band
- **Bluetooth:** 4.0 + EDR
- **Base ROM:** LineageOS 11.0 (Android 4.4)

## Important Notes

The soho is more challenging than the ariel:

1. **No existing LineageOS device tree for soho specifically.** We adapt the "tate" tree (Kindle Fire HD 7 2012, OMAP4460). The OMAP4470 is very similar to the OMAP4460 with minor clock and GPU differences.
2. **The ROM base is older** (Android 4.4 vs 7.1.2 for ariel), which limits app compatibility.
3. **postmarketOS reports** that 3D acceleration, audio, and bluetooth are untested/broken on their downstream kernel. LineageOS 11.0 has better driver support since it uses Amazon's kernel.

## Prerequisites

Same as ariel, plus:
- Familiarity with Android device tree structure (you'll be editing BoardConfig.mk)
- A stock FireOS image for soho (to extract proprietary blobs)

## Step 1: Unlock the Bootloader

The soho uses a fastboot-based unlock method (different from ariel's amonet):

```bash
# Put the tablet into fastboot mode:
# 1. Power off completely
# 2. Hold Volume Down + Power
# 3. Wait for the fastboot menu

# Check current lock status:
fastboot oem device-info

# Unlock (this WIPES all data):
fastboot oem unlock
```

If standard fastboot unlock doesn't work, check XDA for soho-specific exploits. The OMAP4-based Kindles had various bootloader vulnerabilities discovered over the years.

## Step 2: Flash Recovery

```bash
# Use the CM recovery or TWRP for omap4-based Fire tablets
# Check https://xdaforums.com/f/7-kindle-fire-hd-android-development.1786/
fastboot flash recovery recovery-soho.img
fastboot reboot recovery
```

## Step 3: Create the Soho Device Tree

After running `sync-soho.sh`, you'll have the `tate` device tree. Copy and adapt it:

```bash
cd $BUILD_ROOT/soho
cp -r device/amazon/tate device/amazon/soho
```

### Key files to modify in device/amazon/soho:

#### AndroidProducts.mk
```makefile
PRODUCT_MAKEFILES := $(LOCAL_DIR)/lineage_soho.mk
```

#### lineage_soho.mk
```makefile
$(call inherit-product, device/amazon/soho/full_soho.mk)
$(call inherit-product, vendor/lineage/config/common_full_tablet_wifionly.mk)

# Include KindleRewriter customizations
$(call inherit-product-if-exists, vendor/kindle-rewriter/product.mk)

PRODUCT_NAME := lineage_soho
PRODUCT_DEVICE := soho
PRODUCT_BRAND := Amazon
PRODUCT_MODEL := KFTHWI
PRODUCT_MANUFACTURER := Amazon
```

#### BoardConfig.mk
Key differences from tate:
```makefile
# SoC: OMAP4470 (vs OMAP4460 in tate)
TARGET_BOARD_OMAP_CPU := 4470

# GPU: SGX544 (vs SGX540 in tate)
# The SGX544 in OMAP4470 supports higher clock speeds
BOARD_EGL_CFG := device/amazon/soho/egl.cfg

# Display: same 1280x800 resolution
TARGET_SCREEN_HEIGHT := 1280
TARGET_SCREEN_WIDTH := 800

# Kernel
TARGET_KERNEL_SOURCE := kernel/amazon/omap4-common
TARGET_KERNEL_CONFIG := soho_defconfig
# If no soho_defconfig exists, start from tate_defconfig and adjust
```

#### Extract proprietary blobs

From a running stock soho tablet:
```bash
adb root
adb pull /system/lib/hw/ device/amazon/soho/proprietary/lib/hw/
adb pull /system/lib/egl/ device/amazon/soho/proprietary/lib/egl/
adb pull /system/vendor/ device/amazon/soho/proprietary/vendor/
adb pull /system/etc/firmware/ device/amazon/soho/proprietary/etc/firmware/
```

Or extract from the stock firmware image.

## Step 4: Set Up Build Environment

```bash
cd kindleRewriter/scripts
chmod +x *.sh
./setup-build-env.sh
```

## Step 5: Sync and Build

```bash
./sync-soho.sh
# After creating the soho device tree:
./build-soho.sh
```

## Step 6: Flash

See [flashing-guide.md](flashing-guide.md).

## Known Issues

- **Audio:** May require additional HAL configuration. The OMAP4470 audio codec differs slightly from OMAP4460.
- **GPU acceleration:** SGX544 drivers may need specific PowerVR userspace blobs from the stock firmware.
- **WiFi firmware:** Ensure the correct TI WiLink firmware is included. Check `/system/etc/firmware/` from stock.
- **Bluetooth:** May not work without additional firmware blobs.

## Fallback Plan

If building from source proves too difficult for soho, the alternative approach is:

1. Use a pre-built LineageOS 11.0 for tate
2. Flash it to soho (the hardware is similar enough that it may boot)
3. Fix any driver issues post-flash
4. Sideload KidsLauncher.apk and KOReader.apk manually

This is less clean but gets tablets into kids' hands faster.
