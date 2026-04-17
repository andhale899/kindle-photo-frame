#!/bin/sh
##############################################################################
# process_local.sh — On-device photo processor (Zero external dependencies)
# 
# Strategy:
#   - Download images from Google Photos at exact Kindle resolution via URL params
#     (Google resizes server-side: =w1072-h1448-no suffix)
#   - Save directly to vault as PNG — no ImageMagick needed for resize/grayscale
#   - Kindle's blanket framework renders all PNGs in grayscale natively
#   - Weather + date overlay is rendered on screen via eips AFTER image display
#     (see rotate_carousel in update.sh for the eips calls)
#
# Result: Zero dependencies beyond curl (already built-in to all Kindles)
##############################################################################

cd "$(dirname "$0")"
[ -e "config.sh" ] && source ./config.sh
[ -e "utils.sh" ]  && source ./utils.sh

URLS_FILE="${URLS_FILE:-/tmp/kindle_image_urls.txt}"
VAULT_DIR="${VAULT_DIR:-/mnt/us/extensions/onlinescreensaver/vault}"

if [ ! -f "$URLS_FILE" ]; then
    log "PROCESS: ERROR — URLs file not found: $URLS_FILE" "error"
    exit 1
fi

TOTAL=$(wc -l < "$URLS_FILE" | tr -d ' ')
log "PROCESS: Downloading $TOTAL photos to vault (zero-dep mode)"

mkdir -p "$VAULT_DIR"

IDX=1
SUCCESS=0
while IFS= read -r URL; do
    [ -z "$URL" ] && continue

    PADDED=$(printf "%02d" $IDX)
    OUT_PATH="$VAULT_DIR/photo_${PADDED}.png"

    log "PROCESS: [$IDX/$TOTAL] Downloading..."

    # Google Photos URL already has =wW-hH-no suffix from fetch_photos.sh
    # This means Google resizes + crops server-side — we just save the result
    if curl -klL --connect-timeout 10 -m 60 "$URL" -o "$OUT_PATH" 2>/dev/null && [ -s "$OUT_PATH" ]; then
        SUCCESS=$(( SUCCESS + 1 ))
        logger "PROCESS: Saved → photo_${PADDED}.png"
    else
        logger "PROCESS: Failed → photo_${PADDED}.png"
        rm -f "$OUT_PATH"
    fi

    IDX=$(( IDX + 1 ))
done < "$URLS_FILE"

log "PROCESS: Done — $SUCCESS / $TOTAL photos saved to vault" "success"

if [ $SUCCESS -eq 0 ]; then
    log "PROCESS: ERROR — No photos downloaded." "error"
    exit 1
fi
