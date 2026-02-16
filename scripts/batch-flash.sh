#!/usr/bin/env bash
set -euo pipefail

# KindleRewriter: Batch Flash Pipeline
# Automatically detects, identifies, jailbreaks, flashes, and loads books
# onto Fire tablets as they are plugged in via USB.
#
# Usage:
#   ./batch-flash.sh              # Interactive mode: one tablet at a time
#   ./batch-flash.sh --watch      # Watch mode: auto-detect new USB devices
#   ./batch-flash.sh --status     # Show progress of all tablets processed
#
# Designed for processing 50+ tablets on a workstation with a USB hub.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
STATE_DIR="$PROJECT_ROOT/.state"
BOOKS_DIR="$PROJECT_ROOT/books/collection"

# ROM files (set these to your built ROM ZIPs)
ARIEL_ROM="${ARIEL_ROM:-}"
SOHO_ROM="${SOHO_ROM:-}"
ARIEL_RECOVERY="${ARIEL_RECOVERY:-}"
SOHO_RECOVERY="${SOHO_RECOVERY:-}"

# amonet path for ariel bootloader unlock
AMONET_DIR="${AMONET_DIR:-$PROJECT_ROOT/tools/amonet}"

mkdir -p "$LOG_DIR" "$STATE_DIR"

# ---- Color output helpers ----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log() { echo -e "${CYAN}[$(date +%H:%M:%S)]${NC} $1"; }
ok()  { echo -e "${GREEN}[OK]${NC} $1"; }
err() { echo -e "${RED}[ERROR]${NC} $1"; }
warn(){ echo -e "${YELLOW}[WARN]${NC} $1"; }

# ---- Device identification ----

identify_device() {
    local serial="$1"
    local model=""
    local codename=""

    # Try to get model info via ADB (if booted)
    model=$(adb -s "$serial" shell getprop ro.product.model 2>/dev/null || echo "")

    if [ -z "$model" ]; then
        # Try fastboot (if in bootloader mode)
        model=$(fastboot -s "$serial" getvar product 2>&1 | grep "product:" | awk '{print $2}' || echo "")
    fi

    # Identify by known model strings
    case "$model" in
        *KFASWI*|*ariel*|*SQ46CW*)
            codename="ariel"
            ;;
        *KFTHWI*|*soho*|*P48WVB4*)
            codename="soho"
            ;;
        *)
            # Try USB vendor/product ID for MediaTek download mode
            if lsusb 2>/dev/null | grep -q "0e8d:0003"; then
                codename="ariel-download-mode"
            fi
            ;;
    esac

    echo "$codename"
}

detect_device_state() {
    local serial="$1"
    local state=""

    # Check if device is in ADB mode
    if adb -s "$serial" get-state 2>/dev/null | grep -q "device"; then
        # Check if it's already running our ROM
        local rom_version
        rom_version=$(adb -s "$serial" shell getprop ro.kindle_rewriter.version 2>/dev/null || echo "")
        if [ -n "$rom_version" ]; then
            state="flashed"
        else
            state="booted-stock"
        fi
    elif adb -s "$serial" get-state 2>/dev/null | grep -q "recovery"; then
        state="recovery"
    elif fastboot -s "$serial" getvar product 2>/dev/null; then
        state="fastboot"
    else
        state="unknown"
    fi

    echo "$state"
}

# ---- Pipeline stages ----

stage_unlock_ariel() {
    local serial="$1"
    local logfile="$LOG_DIR/${serial}_unlock.log"

    log "Stage: Unlocking bootloader (ariel via amonet)..."

    if [ ! -d "$AMONET_DIR" ]; then
        err "amonet not found at $AMONET_DIR"
        err "Run: git clone https://github.com/R0rt1z2/amonet.git -b mt8135-ariel $AMONET_DIR"
        return 1
    fi

    # The tablet needs to be in MediaTek download mode for amonet
    log "Ensure tablet is in download mode (Vol Down + Power, release Power)"
    log "Press Enter when ready..."
    read -r

    cd "$AMONET_DIR"
    python3 main.py 2>&1 | tee "$logfile"
    cd "$SCRIPT_DIR"

    ok "Bootloader unlocked (ariel)"
}

stage_unlock_soho() {
    local serial="$1"
    local logfile="$LOG_DIR/${serial}_unlock.log"

    log "Stage: Unlocking bootloader (soho via fastboot)..."
    fastboot -s "$serial" oem unlock 2>&1 | tee "$logfile"
    ok "Bootloader unlocked (soho)"
}

stage_flash_recovery() {
    local serial="$1"
    local codename="$2"
    local logfile="$LOG_DIR/${serial}_recovery.log"
    local recovery_img=""

    if [ "$codename" = "ariel" ]; then
        recovery_img="$ARIEL_RECOVERY"
    else
        recovery_img="$SOHO_RECOVERY"
    fi

    if [ -z "$recovery_img" ] || [ ! -f "$recovery_img" ]; then
        err "Recovery image not set or not found for $codename"
        err "Set ARIEL_RECOVERY or SOHO_RECOVERY environment variable"
        return 1
    fi

    log "Stage: Flashing TWRP recovery ($codename)..."
    fastboot -s "$serial" flash recovery "$recovery_img" 2>&1 | tee "$logfile"
    ok "Recovery flashed"

    log "Rebooting into recovery..."
    fastboot -s "$serial" reboot recovery
    sleep 10  # Wait for recovery to boot
}

stage_wipe() {
    local serial="$1"
    local logfile="$LOG_DIR/${serial}_wipe.log"

    log "Stage: Wiping device..."

    # Wait for device to appear in recovery ADB
    local attempts=0
    while ! adb -s "$serial" get-state 2>/dev/null | grep -q "recovery"; do
        attempts=$((attempts + 1))
        if [ "$attempts" -gt 30 ]; then
            err "Timeout waiting for device in recovery mode"
            return 1
        fi
        sleep 2
    done

    # Wipe via TWRP's command line
    adb -s "$serial" shell twrp wipe data 2>&1 | tee "$logfile"
    adb -s "$serial" shell twrp wipe cache 2>&1 | tee -a "$logfile"
    adb -s "$serial" shell twrp wipe dalvik 2>&1 | tee -a "$logfile"

    ok "Device wiped"
}

stage_flash_rom() {
    local serial="$1"
    local codename="$2"
    local logfile="$LOG_DIR/${serial}_flash.log"
    local rom_zip=""

    if [ "$codename" = "ariel" ]; then
        rom_zip="$ARIEL_ROM"
    else
        rom_zip="$SOHO_ROM"
    fi

    if [ -z "$rom_zip" ] || [ ! -f "$rom_zip" ]; then
        err "ROM ZIP not set or not found for $codename"
        err "Set ARIEL_ROM or SOHO_ROM environment variable"
        return 1
    fi

    log "Stage: Flashing ROM ($codename)..."
    log "ROM: $rom_zip"

    # Start sideload on device
    adb -s "$serial" shell twrp sideload 2>/dev/null &
    sleep 3

    # Push the ROM
    adb -s "$serial" sideload "$rom_zip" 2>&1 | tee "$logfile"

    ok "ROM flashed"
}

stage_load_books() {
    local serial="$1"
    local logfile="$LOG_DIR/${serial}_books.log"

    log "Stage: Loading books..."

    if [ ! -d "$BOOKS_DIR" ] || [ -z "$(ls -A "$BOOKS_DIR" 2>/dev/null)" ]; then
        warn "No books in collection. Run ./books/fetch-gutenberg.sh first"
        return 0
    fi

    # Wait for device to fully boot
    log "Waiting for device to boot (this takes 3-5 minutes on first boot)..."
    local attempts=0
    while ! adb -s "$serial" shell getprop sys.boot_completed 2>/dev/null | grep -q "1"; do
        attempts=$((attempts + 1))
        if [ "$attempts" -gt 150 ]; then
            warn "Timeout waiting for boot. Books can be loaded later."
            return 0
        fi
        sleep 2
    done

    # Use the load-books script
    "$SCRIPT_DIR/load-books.sh" -s "$serial" -d "$BOOKS_DIR" 2>&1 | tee "$logfile"

    ok "Books loaded"
}

# ---- Full pipeline for one device ----

process_device() {
    local serial="$1"
    local state_file="$STATE_DIR/$serial"

    log "========================================="
    log "Processing device: $serial"
    log "========================================="

    # Identify the device
    local codename
    codename=$(identify_device "$serial")

    if [ -z "$codename" ]; then
        err "Could not identify device $serial. Is it an ariel or soho?"
        echo "unknown" > "$state_file"
        return 1
    fi

    log "Identified as: $codename"
    echo "identified:$codename" > "$state_file"

    # Detect current state
    local state
    state=$(detect_device_state "$serial")
    log "Current state: $state"

    case "$state" in
        flashed)
            ok "Device already has KindleRewriter ROM!"
            log "Loading books (in case new ones were added)..."
            stage_load_books "$serial"
            echo "complete:$codename" > "$state_file"
            ;;

        booted-stock)
            log "Stock firmware detected. Starting full pipeline..."

            # Step 1: Reboot to fastboot for unlock
            log "Rebooting to fastboot mode..."
            adb -s "$serial" reboot bootloader
            sleep 10

            # Step 2: Unlock
            if [ "$codename" = "ariel" ]; then
                stage_unlock_ariel "$serial"
            else
                stage_unlock_soho "$serial"
            fi
            echo "unlocked:$codename" > "$state_file"

            # Step 3: Flash recovery
            stage_flash_recovery "$serial" "$codename"
            echo "recovery:$codename" > "$state_file"

            # Step 4: Wipe
            stage_wipe "$serial"
            echo "wiped:$codename" > "$state_file"

            # Step 5: Flash ROM
            stage_flash_rom "$serial" "$codename"
            echo "rom:$codename" > "$state_file"

            # Step 6: Reboot
            log "Rebooting into new ROM..."
            adb -s "$serial" reboot 2>/dev/null || true
            echo "rebooting:$codename" > "$state_file"

            # Step 7: Load books
            stage_load_books "$serial"
            echo "complete:$codename" > "$state_file"

            ok "Device $serial ($codename) is DONE!"
            ;;

        recovery)
            log "Device already in recovery mode. Skipping unlock, going to wipe+flash..."
            stage_wipe "$serial"
            codename=${codename:-"unknown"}
            stage_flash_rom "$serial" "$codename"
            adb -s "$serial" reboot 2>/dev/null || true
            stage_load_books "$serial"
            echo "complete:$codename" > "$state_file"
            ok "Device $serial ($codename) is DONE!"
            ;;

        fastboot)
            log "Device in fastboot mode. Starting from unlock..."
            if [ "$codename" = "ariel" ]; then
                # ariel uses amonet, not fastboot unlock
                warn "ariel needs amonet for unlock (download mode, not fastboot)"
                warn "Power off, then hold Vol Down + Power to enter download mode"
                return 1
            fi
            stage_unlock_soho "$serial"
            stage_flash_recovery "$serial" "$codename"
            stage_wipe "$serial"
            stage_flash_rom "$serial" "$codename"
            adb -s "$serial" reboot 2>/dev/null || true
            stage_load_books "$serial"
            echo "complete:$codename" > "$state_file"
            ok "Device $serial ($codename) is DONE!"
            ;;

        *)
            err "Device in unknown state. Try rebooting it."
            echo "error:unknown-state" > "$state_file"
            return 1
            ;;
    esac
}

# ---- Watch mode: auto-detect USB devices ----

watch_mode() {
    log "=== WATCH MODE ==="
    log "Plug in tablets via USB. They will be automatically processed."
    log "Press Ctrl+C to stop."
    echo ""

    local processed=()

    while true; do
        # Get list of connected ADB devices
        local devices
        devices=$(adb devices 2>/dev/null | tail -n +2 | grep -v "^$" | awk '{print $1}')

        # Also check fastboot devices
        local fb_devices
        fb_devices=$(fastboot devices 2>/dev/null | awk '{print $1}')

        # Combine and deduplicate
        local all_devices
        all_devices=$(echo -e "$devices\n$fb_devices" | sort -u | grep -v "^$")

        for serial in $all_devices; do
            # Skip if already processed
            local already_done=false
            for p in "${processed[@]:-}"; do
                if [ "$p" = "$serial" ]; then
                    already_done=true
                    break
                fi
            done

            if [ "$already_done" = true ]; then
                continue
            fi

            # Check if already complete from a previous run
            if [ -f "$STATE_DIR/$serial" ] && grep -q "^complete:" "$STATE_DIR/$serial"; then
                log "Device $serial already processed (skipping)"
                processed+=("$serial")
                continue
            fi

            log "New device detected: $serial"
            if process_device "$serial"; then
                processed+=("$serial")
            else
                warn "Failed to process $serial. Will retry on next detection."
            fi
        done

        sleep 3
    done
}

# ---- Status report ----

show_status() {
    echo ""
    echo "=== KindleRewriter Batch Flash Status ==="
    echo ""

    local total=0
    local complete=0
    local failed=0
    local in_progress=0

    if [ -d "$STATE_DIR" ] && [ -n "$(ls -A "$STATE_DIR" 2>/dev/null)" ]; then
        for state_file in "$STATE_DIR"/*; do
            total=$((total + 1))
            local serial
            serial=$(basename "$state_file")
            local state
            state=$(cat "$state_file")

            case "$state" in
                complete:*)
                    complete=$((complete + 1))
                    echo -e "  ${GREEN}DONE${NC}  $serial ($state)"
                    ;;
                error:*)
                    failed=$((failed + 1))
                    echo -e "  ${RED}FAIL${NC}  $serial ($state)"
                    ;;
                *)
                    in_progress=$((in_progress + 1))
                    echo -e "  ${YELLOW}WIP${NC}   $serial ($state)"
                    ;;
            esac
        done
    fi

    echo ""
    echo "Total: $total | Complete: $complete | Failed: $failed | In Progress: $in_progress"
    echo ""

    if [ -d "$LOG_DIR" ] && [ -n "$(ls -A "$LOG_DIR" 2>/dev/null)" ]; then
        echo "Logs: $LOG_DIR"
    fi
}

# ---- Main ----

check_prerequisites() {
    local missing=false

    if ! command -v adb &>/dev/null; then
        err "adb not found. Install with: sudo apt install adb"
        missing=true
    fi

    if ! command -v fastboot &>/dev/null; then
        err "fastboot not found. Install with: sudo apt install fastboot"
        missing=true
    fi

    if [ -z "$ARIEL_ROM" ] && [ -z "$SOHO_ROM" ]; then
        warn "No ROM ZIPs configured. Set ARIEL_ROM and/or SOHO_ROM environment variables."
        warn "Example: export ARIEL_ROM=/path/to/lineage-14.1-ariel.zip"
    fi

    if [ "$missing" = true ]; then
        exit 1
    fi
}

case "${1:-}" in
    --watch|-w)
        check_prerequisites
        watch_mode
        ;;
    --status|-s)
        show_status
        ;;
    --reset)
        log "Clearing all state (will re-process all devices)"
        rm -rf "$STATE_DIR"/*
        ok "State cleared"
        ;;
    --help|-h)
        echo "KindleRewriter Batch Flash Tool"
        echo ""
        echo "Usage:"
        echo "  $0              Process a single connected device"
        echo "  $0 --watch      Auto-detect and process devices as they're plugged in"
        echo "  $0 --status     Show processing status of all tablets"
        echo "  $0 --reset      Clear state and re-process all devices"
        echo ""
        echo "Environment variables:"
        echo "  ARIEL_ROM       Path to the ariel ROM ZIP"
        echo "  SOHO_ROM        Path to the soho ROM ZIP"
        echo "  ARIEL_RECOVERY  Path to the ariel TWRP recovery image"
        echo "  SOHO_RECOVERY   Path to the soho TWRP recovery image"
        echo "  AMONET_DIR      Path to the amonet exploit tool"
        ;;
    *)
        check_prerequisites

        # Single device mode
        DEVICE_COUNT=$(adb devices 2>/dev/null | tail -n +2 | grep -v "^$" | wc -l)
        FB_COUNT=$(fastboot devices 2>/dev/null | wc -l)

        if [ "$DEVICE_COUNT" -eq 0 ] && [ "$FB_COUNT" -eq 0 ]; then
            err "No devices connected. Plug in a tablet via USB."
            exit 1
        fi

        if [ "$DEVICE_COUNT" -gt 1 ] || [ "$FB_COUNT" -gt 1 ]; then
            warn "Multiple devices detected. Use --watch mode for batch processing."
            log "Or specify a device: adb -s SERIAL ..."
            adb devices -l
            fastboot devices -l 2>/dev/null || true
            exit 1
        fi

        SERIAL=$(adb devices 2>/dev/null | tail -n +2 | grep -v "^$" | awk '{print $1}')
        if [ -z "$SERIAL" ]; then
            SERIAL=$(fastboot devices 2>/dev/null | awk '{print $1}')
        fi

        process_device "$SERIAL"
        ;;
esac
