#!/bin/sh
##############################################################################
# setup.sh — Self-Sufficient Dependency Installer
# Checks for ImageMagick and installs it automatically if missing.
# Tries MRPI first, then falls back to a direct static binary download.
##############################################################################

cd "$(dirname "$0")"
[ -e "config.sh" ] && source ./config.sh
[ -e "utils.sh" ]  && source ./utils.sh

CONVERT_BIN="${CONVERT_PATH:-convert}"
LOCAL_CONVERT="$(pwd)/convert"
DEPS_DIR="$(pwd)/deps"
IMAGEMAGICK_ARM_URL="https://github.com/ImageMagick/ImageMagick/releases/download/7.1.1-38/ImageMagick--gcc-arm.tar.gz"

##############################################################################
# 1. Check if convert is already working
##############################################################################
check_convert() {
    if command -v "$CONVERT_BIN" >/dev/null 2>&1; then
        logger "SETUP: ImageMagick OK at $(command -v $CONVERT_BIN)"
        return 0
    fi
    if [ -x "$LOCAL_CONVERT" ]; then
        logger "SETUP: Using local convert binary at $LOCAL_CONVERT"
        CONVERT_BIN="$LOCAL_CONVERT"
        export CONVERT_BIN
        return 0
    fi
    return 1
}

##############################################################################
# 2. Try MRPI install (most common on jailbroken Kindles)
##############################################################################
try_mrpi_install() {
    MRPI_DIR="/mnt/us/mrpackages"
    MRPI_SCRIPT="/mnt/us/extensions/MRInstaller/mrinstaller.sh"

    if [ ! -f "$MRPI_SCRIPT" ]; then
        logger "SETUP: MRPI not found, skipping."
        return 1
    fi

    logger "SETUP: MRPI found. Downloading ImageMagick package..."
    mkdir -p "$MRPI_DIR"

    # Download ImageMagick MRPI package (armv7 Kindle-compatible)
    MRPI_PKG_URL="https://github.com/andhale899/kindle-photo-frame/releases/download/deps/imagemagick_kindle_arm.bin"
    if curl -klL --connect-timeout 15 -m 120 "$MRPI_PKG_URL" -o "$MRPI_DIR/imagemagick.bin" 2>/dev/null; then
        logger "SETUP: Downloaded ImageMagick package. Running MRPI installer..."
        mntroot rw 2>/dev/null || true
        sh "$MRPI_SCRIPT" --quiet 2>/dev/null
        if check_convert; then
            logger "SETUP: ImageMagick installed via MRPI."
            return 0
        fi
    fi
    logger "SETUP: MRPI install failed."
    return 1
}

##############################################################################
# 3. Fallback: download a static armv7 binary directly
##############################################################################
try_static_binary() {
    logger "SETUP: Attempting static ImageMagick binary download..."
    mkdir -p "$DEPS_DIR"

    TGZ="$DEPS_DIR/imagemagick.tar.gz"
    STATIC_URLS="
https://github.com/SoftFever/OrcaSlicer/releases/download/nightly/ImageMagick-arm-static.tar.gz
https://github.com/andhale899/kindle-photo-frame/releases/download/deps/imagemagick_arm_static.tar.gz
"
    for URL in $STATIC_URLS; do
        logger "SETUP: Trying $URL ..."
        if curl -klL --connect-timeout 15 -m 120 "$URL" -o "$TGZ" 2>/dev/null; then
            tar -xzf "$TGZ" -C "$DEPS_DIR" 2>/dev/null
            # Find the extracted convert binary
            FOUND=$(find "$DEPS_DIR" -name "convert" -type f 2>/dev/null | head -1)
            if [ -n "$FOUND" ]; then
                cp "$FOUND" "$LOCAL_CONVERT"
                chmod +x "$LOCAL_CONVERT"
                CONVERT_BIN="$LOCAL_CONVERT"
                export CONVERT_BIN
                logger "SETUP: Static ImageMagick binary installed at $LOCAL_CONVERT"
                return 0
            fi
        fi
    done
    logger "SETUP: Static binary download failed."
    return 1
}

##############################################################################
# 4. Fallback: no-overlay mode (just download + display, no ImageMagick needed)
##############################################################################
enable_no_overlay_mode() {
    logger "SETUP: ImageMagick unavailable. Enabling NO_OVERLAY mode (raw download only)."
    NO_OVERLAY=1
    export NO_OVERLAY
    # Write to config so future runs remember
    if grep -q "^NO_OVERLAY=" config.sh 2>/dev/null; then
        sed -i "s/^NO_OVERLAY=.*/NO_OVERLAY=1/" config.sh
    else
        echo "NO_OVERLAY=1" >> config.sh
    fi
}

##############################################################################
# Main entrypoint
##############################################################################
setup_dependencies() {
    check_convert && return 0
    logger "SETUP: ImageMagick not found. Attempting auto-install..."

    try_mrpi_install  && return 0
    try_static_binary && return 0

    # All installs failed — fall back to no-overlay mode
    enable_no_overlay_mode
}

setup_dependencies
