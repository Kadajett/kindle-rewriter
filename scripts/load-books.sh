#!/usr/bin/env bash
set -euo pipefail

# KindleRewriter: Batch load free books onto connected tablets via ADB
# Loads curated children's books from a local collection onto the device

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BOOKS_DIR="$PROJECT_ROOT/books/collection"
DEVICE_BOOKS_PATH="/sdcard/Books"

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Load free ebooks onto connected Kindle tablets via ADB."
    echo ""
    echo "Options:"
    echo "  -s SERIAL    Target specific device by serial number"
    echo "  -d DIR       Source directory for books (default: $BOOKS_DIR)"
    echo "  -a           Load to ALL connected devices"
    echo "  -l           List connected devices"
    echo "  -h           Show this help"
    echo ""
    echo "Supported formats: .epub, .pdf, .mobi, .fb2, .txt, .djvu"
}

list_devices() {
    echo "Connected devices:"
    adb devices -l | tail -n +2 | grep -v "^$" || echo "  (none found)"
}

load_books_to_device() {
    local serial="$1"
    local adb_cmd="adb -s $serial"

    echo ""
    echo "=== Loading books to device: $serial ==="

    # Create books directory on device
    $adb_cmd shell "mkdir -p $DEVICE_BOOKS_PATH" 2>/dev/null

    # Count files
    local count=0
    local total
    total=$(find "$BOOKS_DIR" -type f \( -name "*.epub" -o -name "*.pdf" -o -name "*.mobi" -o -name "*.fb2" -o -name "*.txt" -o -name "*.djvu" \) | wc -l)

    if [ "$total" -eq 0 ]; then
        echo "No books found in $BOOKS_DIR"
        echo "Run: ./books/fetch-gutenberg.sh to download free books first"
        return 1
    fi

    echo "Pushing $total books to $DEVICE_BOOKS_PATH..."

    find "$BOOKS_DIR" -type f \( -name "*.epub" -o -name "*.pdf" -o -name "*.mobi" -o -name "*.fb2" -o -name "*.txt" -o -name "*.djvu" \) | while read -r book; do
        count=$((count + 1))
        local filename
        filename=$(basename "$book")
        printf "\r  [%d/%d] %s" "$count" "$total" "$filename"
        $adb_cmd push "$book" "$DEVICE_BOOKS_PATH/$filename" > /dev/null 2>&1
    done

    echo ""
    echo "Done! $total books loaded to $serial"

    # Trigger media scan so KOReader picks them up
    $adb_cmd shell "am broadcast -a android.intent.action.MEDIA_MOUNTED -d file://$DEVICE_BOOKS_PATH" > /dev/null 2>&1
}

# Parse arguments
TARGET_SERIAL=""
ALL_DEVICES=false

while getopts "s:d:alh" opt; do
    case $opt in
        s) TARGET_SERIAL="$OPTARG" ;;
        d) BOOKS_DIR="$OPTARG" ;;
        a) ALL_DEVICES=true ;;
        l) list_devices; exit 0 ;;
        h) usage; exit 0 ;;
        *) usage; exit 1 ;;
    esac
done

# Ensure books directory exists
if [ ! -d "$BOOKS_DIR" ]; then
    echo "Books directory not found: $BOOKS_DIR"
    echo "Run: ./books/fetch-gutenberg.sh to download free books"
    exit 1
fi

# Load to specific device or all
if [ -n "$TARGET_SERIAL" ]; then
    load_books_to_device "$TARGET_SERIAL"
elif [ "$ALL_DEVICES" = true ]; then
    echo "Loading books to ALL connected devices..."
    adb devices | tail -n +2 | grep -v "^$" | awk '{print $1}' | while read -r serial; do
        load_books_to_device "$serial"
    done
else
    # Default: load to single connected device
    DEVICE_COUNT=$(adb devices | tail -n +2 | grep -v "^$" | wc -l)
    if [ "$DEVICE_COUNT" -eq 0 ]; then
        echo "No devices connected. Connect a tablet via USB and enable USB debugging."
        exit 1
    elif [ "$DEVICE_COUNT" -gt 1 ]; then
        echo "Multiple devices connected. Use -s SERIAL or -a for all."
        list_devices
        exit 1
    else
        SERIAL=$(adb devices | tail -n +2 | grep -v "^$" | awk '{print $1}')
        load_books_to_device "$SERIAL"
    fi
fi

echo ""
echo "=== Book loading complete ==="
