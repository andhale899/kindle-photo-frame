#!/bin/sh
##############################################################################
# fetch_photos.sh — Pure-shell Google Photos album scraper
# Replaces scripts/scrape_album.py with curl + grep + awk.
# Outputs: /tmp/kindle_image_urls.txt (one URL per line)
#
# Usage: sh fetch_photos.sh
##############################################################################

cd "$(dirname "$0")"
[ -e "config.sh" ] && source ./config.sh
[ -e "utils.sh" ]  && source ./utils.sh

OUT_FILE="${URLS_FILE:-/tmp/kindle_image_urls.txt}"
ALBUM_URL="${ALBUM_URL:-}"
PHOTO_COUNT="${PHOTO_COUNT:-15}"
KINDLE_W="${KINDLE_W:-1072}"
KINDLE_H="${KINDLE_H:-1448}"
TMP_HTML="/tmp/gphoto_album.html"

# Validate album URL
if [ -z "$ALBUM_URL" ]; then
    log "FETCH: ERROR — ALBUM_URL is not set in config.sh" "error"
    exit 1
fi

log "FETCH: Scraping album: $ALBUM_URL"

##############################################################################
# Step 1: Download the album HTML page
##############################################################################
curl -klL \
    --connect-timeout 15 \
    -m 60 \
    -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/122.0.0.0 Safari/537.36" \
    "$ALBUM_URL" \
    -o "$TMP_HTML" 2>/dev/null

if [ ! -s "$TMP_HTML" ]; then
    log "FETCH: ERROR — Failed to download album page." "error"
    exit 1
fi

##############################################################################
# Step 2: Extract lh3.googleusercontent.com/pw/ URLs
# Same regex as scrape_album.py, done with grep -oE
##############################################################################
RAW_URLS=$(grep -oE 'https://lh3\.googleusercontent\.com/pw/[A-Za-z0-9_-]+' "$TMP_HTML" | sort -u)

URL_COUNT=$(echo "$RAW_URLS" | grep -c 'https://' 2>/dev/null || echo 0)
log "FETCH: Found $URL_COUNT unique image base URLs"

if [ "$URL_COUNT" -eq 0 ]; then
    log "FETCH: ERROR — No image URLs found. Album may be private or Google changed their layout." "error"
    rm -f "$TMP_HTML"
    exit 1
fi

##############################################################################
# Step 3: Randomly pick PHOTO_COUNT images
# Shuffle using awk's srand(), then head to limit count
##############################################################################
SELECTED=$(echo "$RAW_URLS" | awk 'BEGIN{srand()} {print rand(), $0}' | sort -n | awk '{print $2}' | head -n "$PHOTO_COUNT")
SELECTED_COUNT=$(echo "$SELECTED" | grep -c 'https://' 2>/dev/null || echo 0)

log "FETCH: Selected $SELECTED_COUNT / $URL_COUNT images"

##############################################################################
# Step 4: Append Google Photos resize suffix to get Kindle-native resolution
# =w1072-h1448-no  → exact crop to Kindle PW resolution
##############################################################################
rm -f "$OUT_FILE"
echo "$SELECTED" | while read -r base_url; do
    if [ -n "$base_url" ]; then
        echo "${base_url}=w${KINDLE_W}-h${KINDLE_H}-no" >> "$OUT_FILE"
    fi
done

FINAL_COUNT=$(wc -l < "$OUT_FILE" | tr -d ' ')
log "FETCH: Written $FINAL_COUNT download URLs to $OUT_FILE"

rm -f "$TMP_HTML"
