#!/usr/bin/env bash
set -euo pipefail

# Download curated free children's books from Project Gutenberg
# All books are DRM-free and in the public domain

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COLLECTION_DIR="$SCRIPT_DIR/collection"
BOOKLIST="$SCRIPT_DIR/booklist.json"

mkdir -p "$COLLECTION_DIR"

echo "=== Fetching Free Children's Books from Project Gutenberg ==="
echo "Download directory: $COLLECTION_DIR"
echo ""

# Check for dependencies
if ! command -v curl &> /dev/null; then
    echo "Error: curl is required. Install with: sudo apt install curl"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "Warning: jq not found. Using fallback book list."
    echo "Install jq for full booklist support: sudo apt install jq"
    USE_JQ=false
else
    USE_JQ=true
fi

# Curated list of children's/young adult books from Project Gutenberg
# Format: "GUTENBERG_ID|FILENAME|TITLE"
# These are all public domain, appropriate for children/young adults
BOOKS=(
    "11|alice-in-wonderland.epub|Alice's Adventures in Wonderland - Lewis Carroll"
    "12|through-the-looking-glass.epub|Through the Looking-Glass - Lewis Carroll"
    "74|tom-sawyer.epub|The Adventures of Tom Sawyer - Mark Twain"
    "76|huckleberry-finn.epub|Adventures of Huckleberry Finn - Mark Twain"
    "1661|sherlock-holmes.epub|The Adventures of Sherlock Holmes - Arthur Conan Doyle"
    "1342|pride-and-prejudice.epub|Pride and Prejudice - Jane Austen"
    "345|dracula.epub|Dracula - Bram Stoker"
    "84|frankenstein.epub|Frankenstein - Mary Shelley"
    "1232|prince-and-pauper.epub|The Prince and the Pauper - Mark Twain"
    "35|time-machine.epub|The Time Machine - H.G. Wells"
    "36|war-of-the-worlds.epub|The War of the Worlds - H.G. Wells"
    "55|wonderful-wizard-of-oz.epub|The Wonderful Wizard of Oz - L. Frank Baum"
    "16|peter-pan.epub|Peter Pan - J.M. Barrie"
    "1400|great-expectations.epub|Great Expectations - Charles Dickens"
    "2591|grimms-fairy-tales.epub|Grimm's Fairy Tales - Brothers Grimm"
    "514|little-women.epub|Little Women - Louisa May Alcott"
    "1184|count-of-monte-cristo.epub|The Count of Monte Cristo - Alexandre Dumas"
    "2701|moby-dick.epub|Moby Dick - Herman Melville"
    "120|treasure-island.epub|Treasure Island - Robert Louis Stevenson"
    "1260|jane-eyre.epub|Jane Eyre - Charlotte Bronte"
    "219|heart-of-darkness.epub|Heart of Darkness - Joseph Conrad"
    "98|tale-of-two-cities.epub|A Tale of Two Cities - Charles Dickens"
    "43|jekyll-and-hyde.epub|Strange Case of Dr Jekyll and Mr Hyde - R.L. Stevenson"
    "1952|yellow-wallpaper.epub|The Yellow Wallpaper - Charlotte Perkins Gilman"
    "244|study-in-scarlet.epub|A Study in Scarlet - Arthur Conan Doyle"
    "2097|the-railway-children.epub|The Railway Children - E. Nesbit"
    "113|secret-garden.epub|The Secret Garden - Frances Hodgson Burnett"
    "1149|anne-of-green-gables.epub|Anne of Green Gables - L.M. Montgomery"
    "32|herland.epub|Herland - Charlotte Perkins Gilman"
    "45|anne-of-avonlea.epub|Anne of Avonlea - L.M. Montgomery"
    "1257|three-musketeers.epub|The Three Musketeers - Alexandre Dumas"
    "158|emma.epub|Emma - Jane Austen"
    "161|sense-and-sensibility.epub|Sense and Sensibility - Jane Austen"
    "174|picture-of-dorian-gray.epub|The Picture of Dorian Gray - Oscar Wilde"
    "2852|hound-of-the-baskervilles.epub|The Hound of the Baskervilles - Arthur Conan Doyle"
    "17396|my-man-jeeves.epub|My Man Jeeves - P.G. Wodehouse"
    "164|twenty-thousand-leagues.epub|Twenty Thousand Leagues Under the Sea - Jules Verne"
    "103|around-the-world-80-days.epub|Around the World in Eighty Days - Jules Verne"
    "375|black-beauty.epub|Black Beauty - Anna Sewell"
    "28885|wind-in-the-willows.epub|The Wind in the Willows - Kenneth Grahame"
)

TOTAL=${#BOOKS[@]}
COUNT=0
SKIPPED=0
DOWNLOADED=0

for entry in "${BOOKS[@]}"; do
    IFS='|' read -r id filename title <<< "$entry"
    COUNT=$((COUNT + 1))
    DEST="$COLLECTION_DIR/$filename"

    if [ -f "$DEST" ]; then
        printf "[%d/%d] Already have: %s\n" "$COUNT" "$TOTAL" "$title"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    printf "[%d/%d] Downloading: %s..." "$COUNT" "$TOTAL" "$title"

    # Project Gutenberg EPUB download URL pattern
    URL="https://www.gutenberg.org/ebooks/${id}.epub3.images"

    if curl -sL -o "$DEST" "$URL" 2>/dev/null; then
        # Verify we got an actual EPUB (not an error page)
        if file "$DEST" | grep -q "Zip\|EPUB"; then
            echo " OK"
            DOWNLOADED=$((DOWNLOADED + 1))
        else
            echo " FAILED (not a valid EPUB)"
            rm -f "$DEST"
            # Try alternate URL format
            ALT_URL="https://www.gutenberg.org/ebooks/${id}.epub.images"
            printf "  Trying alternate URL..."
            if curl -sL -o "$DEST" "$ALT_URL" 2>/dev/null && file "$DEST" | grep -q "Zip\|EPUB"; then
                echo " OK"
                DOWNLOADED=$((DOWNLOADED + 1))
            else
                echo " FAILED"
                rm -f "$DEST"
            fi
        fi
    else
        echo " FAILED (network error)"
    fi

    # Be polite to Project Gutenberg servers
    sleep 1
done

echo ""
echo "=== Download complete ==="
echo "  Downloaded: $DOWNLOADED"
echo "  Skipped (already had): $SKIPPED"
echo "  Total in collection: $(find "$COLLECTION_DIR" -name "*.epub" | wc -l) books"
echo ""
echo "Collection: $COLLECTION_DIR"
echo "Next: run ./scripts/load-books.sh to push to connected tablets"
