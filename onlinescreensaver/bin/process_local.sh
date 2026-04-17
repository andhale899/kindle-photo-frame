#!/bin/sh
##############################################################################
# process_local.sh — On-device photo processor
# Replaces scripts/process_photos.py.
# Uses curl (download) + ImageMagick convert (resize/grayscale/overlay).
# Falls back to raw download (no overlay) if ImageMagick is unavailable.
#
# Usage: sh process_local.sh
##############################################################################

cd "$(dirname "$0")"
[ -e "config.sh" ] && source ./config.sh
[ -e "utils.sh" ]  && source ./utils.sh

URLS_FILE="${URLS_FILE:-/tmp/kindle_image_urls.txt}"
VAULT_DIR="${VAULT_DIR:-/mnt/us/extensions/onlinescreensaver/vault}"
KINDLE_W="${KINDLE_W:-1072}"
KINDLE_H="${KINDLE_H:-1448}"
CONVERT_BIN="${CONVERT_BIN:-convert}"
NO_OVERLAY="${NO_OVERLAY:-0}"

WEATHER_LOCATION="${WEATHER_LOCATION:-Ahmednagar, IN}"
WEATHER_UNITS="${WEATHER_UNITS:-C}"

##############################################################################
# Detect ImageMagick
##############################################################################
if ! command -v "$CONVERT_BIN" >/dev/null 2>&1; then
    if [ -x "$(pwd)/convert" ]; then
        CONVERT_BIN="$(pwd)/convert"
    else
        logger "PROCESS: ImageMagick not found. Using NO_OVERLAY mode."
        NO_OVERLAY=1
    fi
fi

##############################################################################
# Fetch weather via wttr.in plain-text API (no JSON parsing needed)
# Returns e.g. "+28°C Sunny"
##############################################################################
fetch_weather() {
    if [ "${ENABLE_WEATHER:-1}" != "1" ]; then
        WEATHER_TEXT=""
        return
    fi

    LOCATION_ENC=$(echo "$WEATHER_LOCATION" | sed 's/ /%20/g; s/,/%2C/g')
    # Format: %t = temperature, %C = condition text
    WEATHER_TEXT=$(curl -sk --connect-timeout 10 -m 15 \
        "https://wttr.in/${LOCATION_ENC}?format=%t+%C" 2>/dev/null | tr -d '\n')

    # Sanitise — strip non-ASCII and fix degree sign for ImageMagick
    WEATHER_TEXT=$(echo "$WEATHER_TEXT" | sed 's/[^0-9a-zA-Z°+\-\. ]//g' | cut -c1-40)
    logger "PROCESS: Weather: $WEATHER_TEXT"
}

##############################################################################
# Fetch date string
##############################################################################
fetch_date() {
    DATE_TEXT=$(date '+%A, %d %B')    # e.g. "Thursday, 17 April"
}

##############################################################################
# Process one image: download → resize/crop → grayscale → overlay → save
##############################################################################
process_image() {
    URL="$1"
    OUT_PATH="$2"
    TMP_DL="/tmp/kindle_dl_$$.jpg"
    TMP_GRAY="/tmp/kindle_gray_$$.png"

    # Download
    if ! curl -klL --connect-timeout 10 -m 60 "$URL" -o "$TMP_DL" 2>/dev/null; then
        logger "PROCESS: Download failed: $URL"
        rm -f "$TMP_DL"
        return 1
    fi

    if [ ! -s "$TMP_DL" ]; then
        logger "PROCESS: Downloaded file is empty: $URL"
        rm -f "$TMP_DL"
        return 1
    fi

    if [ "$NO_OVERLAY" = "1" ]; then
        # No ImageMagick — just copy the downloaded file to vault
        # Google already resized it to Kindle res via the =wXXX-hYYY suffix on the URL
        mv "$TMP_DL" "$OUT_PATH"
        logger "PROCESS: Saved (no-overlay) → $(basename "$OUT_PATH")"
        return 0
    fi

    # ImageMagick pipeline (single chained command for efficiency):
    # 1. Resize + centre-crop to exact Kindle dimensions
    # 2. Convert to 8-bit grayscale (mode L)
    # 3. Apply mild unsharp mask (sharpens e-ink display)
    # 4. Draw date overlay (bottom-left, shadowed white text)
    # 5. Draw weather overlay (bottom-right, shadowed white text)
    # 6. Save as optimised PNG

    FONT_SIZE_DATE=72
    FONT_SIZE_WEATHER=60
    PAD=60

    # Position: bottom-left for date, bottom-right for weather
    DATE_X=$PAD
    DATE_Y=$(( KINDLE_H - PAD - FONT_SIZE_DATE - FONT_SIZE_WEATHER - 20 ))
    WEATHER_X=$(( KINDLE_W - PAD ))
    WEATHER_Y=$DATE_Y

    "$CONVERT_BIN" "$TMP_DL" \
        -resize "${KINDLE_W}x${KINDLE_H}^" \
        -gravity Center \
        -extent "${KINDLE_W}x${KINDLE_H}" \
        -colorspace Gray \
        -depth 8 \
        -unsharp 1.2x1.2+1.0+0.05 \
        \
        -font DejaVu-Sans-Bold \
        \
        -fill black  -annotate "+$(( DATE_X + 2 ))+$(( DATE_Y + 2 ))"    "$DATE_TEXT" \
        -fill white  -annotate "+${DATE_X}+${DATE_Y}"                     "$DATE_TEXT" \
        \
        -gravity SouthEast \
        -fill black  -annotate "+$(( PAD - 2 ))+$(( PAD + FONT_SIZE_WEATHER + 24 ))" "$WEATHER_TEXT" \
        -fill white  -annotate "+${PAD}+$(( PAD + FONT_SIZE_WEATHER + 22 ))"          "$WEATHER_TEXT" \
        \
        -pointsize "$FONT_SIZE_DATE" \
        -gravity SouthWest \
        -fill black  -annotate "+$(( PAD + 2 ))+$(( PAD + 2 ))" "$DATE_TEXT" \
        -fill white  -annotate "+${PAD}+${PAD}"                  "$DATE_TEXT" \
        \
        -pointsize "$FONT_SIZE_WEATHER" \
        -gravity SouthEast \
        -fill black  -annotate "+$(( PAD + 2 ))+$(( PAD + 2 ))" "$WEATHER_TEXT" \
        -fill white  -annotate "+${PAD}+${PAD}"                  "$WEATHER_TEXT" \
        \
        -define png:color-type=0 \
        "$OUT_PATH" 2>/dev/null

    RET=$?
    rm -f "$TMP_DL" "$TMP_GRAY"

    if [ $RET -ne 0 ]; then
        logger "PROCESS: ImageMagick failed for $(basename "$OUT_PATH")"
        return 1
    fi

    logger "PROCESS: Saved → $(basename "$OUT_PATH")"
    return 0
}

##############################################################################
# Main
##############################################################################
if [ ! -f "$URLS_FILE" ]; then
    log "PROCESS: ERROR — URLs file not found: $URLS_FILE" "error"
    exit 1
fi

TOTAL=$(wc -l < "$URLS_FILE" | tr -d ' ')
log "PROCESS: Processing $TOTAL photos (ImageMagick: $([ "$NO_OVERLAY" = "1" ] && echo OFF || echo ON))"

# Fetch shared weather + date once (not per-photo)
fetch_weather
fetch_date

mkdir -p "$VAULT_DIR"

IDX=1
SUCCESS=0
while IFS= read -r URL; do
    [ -z "$URL" ] && continue

    PADDED=$(printf "%02d" $IDX)
    OUT_PATH="$VAULT_DIR/photo_${PADDED}.png"

    log "PROCESS: [$IDX/$TOTAL] Processing..."

    if process_image "$URL" "$OUT_PATH"; then
        SUCCESS=$(( SUCCESS + 1 ))
    fi

    IDX=$(( IDX + 1 ))
done < "$URLS_FILE"

log "PROCESS: Done — $SUCCESS / $TOTAL photos saved to vault" "success"

if [ $SUCCESS -eq 0 ]; then
    log "PROCESS: ERROR — No photos processed." "error"
    exit 1
fi
