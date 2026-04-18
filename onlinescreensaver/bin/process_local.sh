#!/bin/sh
##############################################################################
# process_local.sh — On-device photo processor
#
# Downloads photos from Google Photos and embeds date + weather text
# directly into the image file (no eips, no separate screen writes).
#
# Requires: bundled ImageMagick 'convert' binary (included in MRPI package)
#           curl (built into all Kindles)
#
# Image pipeline per photo:
#   1. Download at Kindle-native resolution via Google Photos URL params
#      (=w1072-h1448-no  →  exact crop to Kindle PW size by Google's servers)
#   2. Use bundled 'convert' to embed date + weather text as a permanent overlay
#   3. Save to vault as PNG
##############################################################################

cd "$(dirname "$0")"
[ -e "config.sh" ] && source ./config.sh
[ -e "utils.sh" ]  && source ./utils.sh
[ -e "secrets.sh" ] && source ./secrets.sh

URLS_FILE="${URLS_FILE:-/tmp/kindle_image_urls.txt}"
VAULT_DIR="${VAULT_DIR:-/mnt/us/extensions/onlinescreensaver/vault}"
KINDLE_W="${KINDLE_W:-1072}"
KINDLE_H="${KINDLE_H:-1448}"

# Bundled ImageMagick lives next to the scripts in the extension's bin/ folder
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIBS_DIR="$SCRIPT_DIR/libs"
CONVERT_BIN="$SCRIPT_DIR/convert"

# Check if bundled convert is available
HAS_CONVERT=0
if [ -x "$CONVERT_BIN" ]; then
    HAS_CONVERT=1
else
    logger "PROCESS: WARNING — bundled convert not found at $CONVERT_BIN. Text overlay disabled."
fi

##############################################################################
# Fetch current weather (plain text, zero parsing)
# wttr.in ?format=%t+%C  →  "+28°C Sunny"
##############################################################################
fetch_weather() {
    WEATHER_TEXT=""
    [ "${ENABLE_WEATHER:-1}" != "1" ] && return

    LOCATION_ENC=$(echo "${WEATHER_LOCATION:-Ahmednagar}" | sed 's/ /+/g; s/,/%2C/g')
    RAW=$(curl -sk --connect-timeout 8 -m 12 \
        "https://wttr.in/${LOCATION_ENC}?format=%t+%C" 2>/dev/null)

    # Remove non-ASCII + degree symbol trick for ImageMagick compatibility
    WEATHER_TEXT=$(echo "$RAW" | tr -cd '[:print:]' | sed 's/  */ /g' | cut -c1-35)
    logger "PROCESS: Weather → $WEATHER_TEXT"
}

##############################################################################
# Embed date + weather text overlay into an image (in-place)
# Uses ImageMagick convert with:
#   - Drop shadow (offset copy drawn first in black)
#   - White text on top
#   - SouthWest gravity for date, SouthEast for weather
##############################################################################
embed_overlay() {
    IMG_PATH="$1"
    [ ! -f "$IMG_PATH" ] && return 1
    [ "$HAS_CONVERT" -eq 0 ] && return 0   # skip silently if no convert

    # Date: "Thursday 17 Apr"
    DATE_TEXT=$(date '+%A %d %b')
    PAD=50
    SZ_DATE=56
    SZ_WEATHER=44
    SHADOW=3   # shadow offset px

    TMP_OUT="/tmp/kindle_overlay_$$.png"

    # Draw both overlays in a single convert pipeline:
    #   1. Convert to grayscale (8-bit) 
    #   2. Shadow pass (black, offset) for date
    #   3. Foreground pass (white) for date
    #   4. Shadow pass for weather  
    #   5. Foreground pass for weather
    env LD_LIBRARY_PATH="$LIBS_DIR" MAGICK_HOME="$SCRIPT_DIR" MAGICK_CONFIGURE_PATH="$LIBS_DIR" \
    "$CONVERT_BIN" "$IMG_PATH" \
        -colorspace Gray -depth 8 \
        \( -clone 0 \
           -fill black \
           -gravity SouthWest \
           -pointsize "$SZ_DATE" \
           -annotate "+$((PAD + SHADOW))+$((PAD - SHADOW))" "$DATE_TEXT" \
        \) -composite \
        \( -clone 0 \
           -fill white \
           -gravity SouthWest \
           -pointsize "$SZ_DATE" \
           -annotate "+${PAD}+${PAD}" "$DATE_TEXT" \
        \) -composite \
        \( -clone 0 \
           -fill black \
           -gravity SouthEast \
           -pointsize "$SZ_WEATHER" \
           -annotate "+$((PAD + SHADOW))+$((PAD - SHADOW))" "$WEATHER_TEXT" \
        \) -composite \
        \( -clone 0 \
           -fill white \
           -gravity SouthEast \
           -pointsize "$SZ_WEATHER" \
           -annotate "+${PAD}+${PAD}" "$WEATHER_TEXT" \
        \) -composite \
        -define png:color-type=0 \
        "$TMP_OUT" 2>/dev/null

    if [ $? -eq 0 ] && [ -s "$TMP_OUT" ]; then
        mv "$TMP_OUT" "$IMG_PATH"
    else
        logger "PROCESS: embed_overlay failed — keeping image without overlay"
        rm -f "$TMP_OUT"
    fi
}

##############################################################################
# Main
##############################################################################
if [ ! -f "$URLS_FILE" ]; then
    log "PROCESS: ERROR — URLs file not found: $URLS_FILE" "error"
    exit 1
fi

TOTAL=$(wc -l < "$URLS_FILE" | tr -d ' ')
log "PROCESS: Downloading $TOTAL photos (overlay: $([ "$HAS_CONVERT" -eq 1 ] && echo embedded || echo disabled))"

# Fetch weather once (same for all photos in this cycle)
fetch_weather

mkdir -p "$VAULT_DIR"

IDX=1
SUCCESS=0
while IFS= read -r URL; do
    [ -z "$URL" ] && continue

    PADDED=$(printf "%02d" $IDX)
    OUT_PATH="$VAULT_DIR/photo_${PADDED}.png"

    log "PROCESS: [$IDX/$TOTAL] Downloading..."

    # Google resizes image server-side via the =w-h-no URL suffix
    if curl -klL --connect-timeout 10 -m 60 "$URL" -o "$OUT_PATH" 2>/dev/null && [ -s "$OUT_PATH" ]; then
        # Embed date + weather directly into the image file
        embed_overlay "$OUT_PATH"
        SUCCESS=$(( SUCCESS + 1 ))
        logger "PROCESS: Done → photo_${PADDED}.png"
    else
        logger "PROCESS: Failed → photo_${PADDED}.png"
        rm -f "$OUT_PATH"
    fi

    IDX=$(( IDX + 1 ))
done < "$URLS_FILE"

log "PROCESS: Done — $SUCCESS / $TOTAL photos saved to vault" "success"

if [ $SUCCESS -eq 0 ]; then
    log "PROCESS: ERROR — No photos processed." "error"
    exit 1
fi
