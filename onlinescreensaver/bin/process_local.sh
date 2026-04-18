#!/bin/sh
##############################################################################
# process_local.sh -- On-device photo processor
#
# Downloads photos from Google Photos and embeds date + weather text
# directly into the image file (no eips, no separate screen writes).
#
# Requires: bundled ImageMagick 'convert' binary (included in package)
#           curl (built into all Kindles)
##############################################################################

cd "$(dirname "$0")"
[ -e "config.sh" ] && source ./config.sh
[ -e "utils.sh" ]  && source ./utils.sh
[ -e "secrets.sh" ] && source ./secrets.sh

URLS_FILE="${URLS_FILE:-/tmp/kindle_image_urls.txt}"
VAULT_DIR="${VAULT_DIR:-/mnt/us/extensions/onlinescreensaver/vault}"
KINDLE_W="${KINDLE_W:-1072}"
KINDLE_H="${KINDLE_H:-1448}"

# Bundled ImageMagick — Alpine/musl binary, invoked via bundled ld-musl loader
# The Kindle runs glibc so we must use the musl loader explicitly, otherwise
# the kernel reports "not found" when trying to resolve /lib/ld-musl-armhf.so.1
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIBS_DIR="$SCRIPT_DIR/libs"
CONVERT_BIN="$SCRIPT_DIR/convert"
MUSL_LOADER="$LIBS_DIR/ld-musl-armhf.so.1"

logger "PROCESS: SCRIPT_DIR=$SCRIPT_DIR"
logger "PROCESS: CONVERT_BIN=$CONVERT_BIN"

# Check if both the convert binary and musl loader are present
HAS_CONVERT=0
if [ -x "$CONVERT_BIN" ] && [ -x "$MUSL_LOADER" ]; then
    HAS_CONVERT=1
    logger "PROCESS: convert + musl loader found OK"
else
    logger "PROCESS: WARNING - convert or musl loader missing. Text overlay disabled."
    logger "PROCESS:   convert: $(ls $CONVERT_BIN 2>&1)"
    logger "PROCESS:   musl:    $(ls $MUSL_LOADER 2>&1)"
fi

##############################################################################
# Fetch current weather
# wttr.in ?format=%t+%C  ->  "+28C Sunny"
##############################################################################
fetch_weather() {
    WEATHER_TEXT=""
    [ "${ENABLE_WEATHER:-1}" != "1" ] && return

    LOCATION_ENC=$(echo "${WEATHER_LOCATION:-Ahmednagar}" | sed 's/ /+/g; s/,/%2C/g')
    RAW=$(curl -sk --connect-timeout 8 -m 12 \
        "https://wttr.in/${LOCATION_ENC}?format=%t+%C" 2>/dev/null)

    # Remove non-ASCII characters so ImageMagick handles it cleanly
    WEATHER_TEXT=$(echo "$RAW" | tr -cd '[:print:][:space:]' | tr -d '\r' | sed 's/  */ /g' | cut -c1-30)
    logger "PROCESS: Weather: $WEATHER_TEXT"
}

##############################################################################
# Embed date + weather text overlay into an image (in-place)
##############################################################################
embed_overlay() {
    IMG_PATH="$1"
    [ ! -f "$IMG_PATH" ] && return 1
    [ "$HAS_CONVERT" -eq 0 ] && return 0   # skip silently if no convert

    DATE_TEXT=$(date '+%A %d %b')
    PAD=50
    SZ_DATE=56
    SZ_WEATHER=44
    SHADOW=3

    TMP_OUT="/tmp/kindle_overlay_$$.png"

    # Invoke convert via the bundled musl loader (Kindle uses glibc, not musl)
    env LD_LIBRARY_PATH="$LIBS_DIR" \
        MAGICK_HOME="$SCRIPT_DIR" \
        MAGICK_CONFIGURE_PATH="$LIBS_DIR" \
    "$MUSL_LOADER" "$CONVERT_BIN" "$IMG_PATH" \
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
        "$TMP_OUT" 2>/tmp/convert_err_$$.txt

    CONV_RET=$?
    if [ $CONV_RET -eq 0 ] && [ -s "$TMP_OUT" ]; then
        mv "$TMP_OUT" "$IMG_PATH"
        logger "PROCESS: overlay embedded OK"
    else
        CONV_ERR=$(cat /tmp/convert_err_$$.txt 2>/dev/null | head -3)
        logger "PROCESS: embed_overlay failed (exit=$CONV_RET): $CONV_ERR"
        rm -f "$TMP_OUT"
    fi
    rm -f "/tmp/convert_err_$$.txt"
}

##############################################################################
# Main
##############################################################################
if [ ! -f "$URLS_FILE" ]; then
    log "PROCESS: ERROR - URLs file not found: $URLS_FILE" "error"
    exit 1
fi

TOTAL=$(wc -l < "$URLS_FILE" | tr -d ' ')
if [ "$HAS_CONVERT" -eq 1 ]; then
    OVERLAY_STATUS="embedded"
else
    OVERLAY_STATUS="disabled (convert not found)"
fi
log "PROCESS: Downloading $TOTAL photos (overlay: $OVERLAY_STATUS)"

fetch_weather

mkdir -p "$VAULT_DIR"

IDX=1
SUCCESS=0
while IFS= read -r URL; do
    [ -z "$URL" ] && continue

    PADDED=$(printf "%02d" $IDX)
    OUT_PATH="$VAULT_DIR/photo_${PADDED}.png"

    log "PROCESS: [$IDX/$TOTAL] Downloading photo_${PADDED}.png..."

    if curl -klL --connect-timeout 10 -m 60 "$URL" -o "$OUT_PATH" 2>/dev/null && [ -s "$OUT_PATH" ]; then
        SZ=$(ls -la "$OUT_PATH" 2>/dev/null | awk '{print $5}')
        logger "PROCESS: Downloaded ${SZ} bytes -> photo_${PADDED}.png"
        embed_overlay "$OUT_PATH"
        SUCCESS=$(( SUCCESS + 1 ))
    else
        logger "PROCESS: Download failed -> photo_${PADDED}.png"
        rm -f "$OUT_PATH"
    fi

    IDX=$(( IDX + 1 ))
done < "$URLS_FILE"

log "PROCESS: Done - $SUCCESS / $TOTAL photos saved to vault" "success"

if [ $SUCCESS -eq 0 ]; then
    log "PROCESS: ERROR - No photos processed." "error"
    exit 1
fi
