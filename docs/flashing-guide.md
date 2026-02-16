# Flashing Guide: KindleRewriter ROM

Step-by-step guide for flashing KindleRewriter onto Fire tablets. Written for volunteers who may not be technical.

## What You Need

- A computer running Linux (Ubuntu preferred) or Windows with ADB installed
- USB cable (data-capable, not charge-only)
- The built ROM ZIP file (from the build scripts)
- The correct TWRP recovery image for your tablet model
- A tablet with an unlocked bootloader

## Identify Your Tablet

| Look for this model number | Device name | Codename |
|---|---|---|
| **SQ46CW** (on back label) | Fire HD 7 4th Gen (2014) | ariel |
| **P48WVB4** (on back label) | Kindle Fire HD 7 3rd Gen (2013) | soho |

## Before You Start

1. **Charge the tablet to at least 50%**
2. **This will ERASE everything on the tablet.** That's fine for donated tablets.
3. **Enable USB debugging** (if the tablet still boots):
   - Settings > Device Options > tap "Serial Number" 7 times to enable Developer Options
   - Settings > Device Options > Developer Options > Enable USB Debugging
   - Connect USB and approve the debugging prompt on the tablet

## Phase 1: Unlock Bootloader

### For SQ46CW (ariel)

Uses the amonet exploit:

```bash
git clone https://github.com/R0rt1z2/amonet.git -b mt8135-ariel
cd amonet

# Enter download mode on the tablet:
#   1. Power off completely (hold power 10 seconds)
#   2. Hold Volume Down + Power until screen goes black
#   3. Release Power, keep holding Volume Down
#   4. Connect USB cable to computer

python3 main.py
# Follow the on-screen prompts
```

### For P48WVB4 (soho)

Uses fastboot:

```bash
# Enter fastboot mode on the tablet:
#   1. Power off completely
#   2. Hold Volume Down + Power
#   3. When you see the fastboot screen, release both buttons
#   4. Connect USB cable

fastboot oem unlock
# The tablet will wipe and reboot
```

## Phase 2: Flash Custom Recovery (TWRP)

With the bootloader unlocked and tablet in fastboot mode:

```bash
# For ariel:
fastboot flash recovery twrp-ariel.img

# For soho:
fastboot flash recovery twrp-soho.img

# Reboot into recovery:
fastboot reboot recovery
```

**Alternative way to enter recovery** (if tablet reboots to normal OS):
- Power off
- Hold Volume Up + Power until you see the recovery menu
- If that doesn't work: hold Volume Down + Power, then release and quickly press Volume Up

## Phase 3: Flash the ROM

### Method A: ADB Sideload (recommended)

With the tablet in TWRP recovery:

1. In TWRP, tap **Wipe** > **Advanced Wipe**
2. Select: **Dalvik/ART Cache**, **System**, **Data**, **Cache**
3. Swipe to wipe
4. Go back, tap **Advanced** > **ADB Sideload**
5. Swipe to start sideload
6. On your computer:

```bash
# For ariel:
adb sideload lineage-14.1-*-ariel.zip

# For soho:
adb sideload lineage-11.0-*-soho.zip
```

7. Wait for the transfer and installation to complete (5-10 minutes)
8. Tap **Reboot System**

### Method B: SD Card / USB Storage

1. Copy the ROM ZIP to a microSD card or USB OTG drive
2. In TWRP, tap **Install**
3. Navigate to the ZIP file
4. Swipe to flash
5. Reboot

## Phase 4: First Boot

1. First boot takes 3-5 minutes. The screen may stay black for a while. Be patient.
2. You should see the KidsLauncher home screen with three options:
   - **Read Books** (opens KOReader)
   - **Browse Web** (opens the browser)
   - **My Files** (opens the file manager)
3. Connect to WiFi through the notification shade (swipe down from top)

## Phase 5: Load Books

With the tablet booted and connected via USB:

```bash
# From the kindleRewriter directory:
# First, download the book collection (one time):
./books/fetch-gutenberg.sh

# Then push books to the connected tablet:
./scripts/load-books.sh
```

Or to load to ALL connected tablets at once:
```bash
./scripts/load-books.sh -a
```

## Batch Flashing Tips

When flashing many tablets at once:

1. **Set up a workstation** with a USB hub (powered, USB 2.0 preferred)
2. **Label each tablet** with its model number before starting
3. **Sort into ariel and soho piles** first
4. **Flash one model at a time** so you don't mix up ROM ZIPs
5. **Use `adb devices`** to see all connected tablets and their serial numbers
6. **The book loading script supports `-a` flag** to push to all connected devices

### Parallel flashing

You can flash multiple tablets simultaneously if they're at different stages:
- Tablet 1: sideloading ROM (takes 5-10 min)
- Tablet 2: wiping (takes 1 min)
- Tablet 3: loading books (takes 2-5 min)

Just specify the device serial: `adb -s SERIAL_NUMBER sideload rom.zip`

## Troubleshooting

### Tablet won't enter download/fastboot mode
- Try a different USB cable (some cables are charge-only)
- Try a USB 2.0 port (not USB 3.0)
- Hold the button combination for at least 15 seconds
- If the battery is completely dead, charge for 30 minutes first

### ADB doesn't see the device
```bash
# Check USB permissions (Linux):
sudo adb kill-server
sudo adb start-server
adb devices

# If still not showing, add udev rules:
echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="1949", MODE="0666"' | sudo tee -a /etc/udev/rules.d/51-amazon.rules
echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="0e8d", MODE="0666"' | sudo tee -a /etc/udev/rules.d/51-mediatek.rules
sudo udevadm control --reload-rules
```

### Tablet bootloops after flashing
- Reboot into TWRP recovery
- Wipe Dalvik/ART Cache and Cache
- Try flashing again
- If it persists, do a full wipe (including Data) and flash again

### KOReader doesn't see books
- Books must be in `/sdcard/Books/` on the device
- Run the `load-books.sh` script again
- Open KOReader and navigate to the Books folder manually
- Some formats (.txt) may need to be opened explicitly

### Screen stays black on first boot
- Wait at least 5 minutes
- If still black, hold Power for 30 seconds to force reboot
- Try booting into recovery and reflashing
