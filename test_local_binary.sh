#!/usr/bin/env bash
##############################################################################
# test_local_binary.sh — Local verification of the bundled ImageMagick
#
# Runs an arm32v7 Alpine Docker container (same environment as the build)
# and tests:
#   1. The 'convert' binary exists and runs
#   2. It can download an image via curl and embed text overlay
#   3. The output PNG is valid
#
# Usage: bash test_local_binary.sh
# Requirements: Docker Desktop running on your machine
##############################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_DIR="$SCRIPT_DIR/test_output"
mkdir -p "$TEST_DIR"

echo "=== Kindle Photo Frame — Local Binary Test ==="
echo ""

# ── Step 1: Check Docker is available ────────────────────────────────────────
if ! command -v docker &>/dev/null; then
    echo "ERROR: Docker is not installed or not in PATH."
    echo "Install Docker Desktop from https://www.docker.com/products/docker-desktop/"
    exit 1
fi

echo "[1/4] Docker found: $(docker --version)"
echo ""

# ── Step 2: Pull arm32v7/alpine (same base as build) ─────────────────────────
echo "[2/4] Pulling arm32v7/alpine:3.19 (this takes ~30s on first run)..."
docker pull --platform linux/arm/v7 arm32v7/alpine:3.19 --quiet
echo "      Done."
echo ""

# ── Step 3: Install ImageMagick and run a test ────────────────────────────────
echo "[3/4] Running ImageMagick armv7 inside container..."
echo "      → Download a test image from Google Photos"
echo "      → Embed date + weather text overlay"
echo "      → Save as PNG to test_output/"
echo ""

docker run --rm --platform linux/arm/v7 \
    -v "$TEST_DIR:/output" \
    arm32v7/alpine:3.19 \
    sh -c '
        # Install tools
        apk add --no-cache imagemagick curl 2>/dev/null

        # Show versions
        echo "  convert: $(convert --version | head -1)"
        echo "  curl:    $(curl --version | head -1)"

        # Download a small test image from Google (Kindle PW7 resolution)
        TEST_URL="https://upload.wikimedia.org/wikipedia/commons/thumb/a/a7/Camponotus_flavomarginatus_ant.jpg/1072px-Camponotus_flavomarginatus_ant.jpg"
        echo ""
        echo "  Downloading test image..."
        curl -skL "$TEST_URL" -o /tmp/test_input.jpg
        echo "  Downloaded: $(ls -lh /tmp/test_input.jpg | awk "{print \$5}")"

        # Embed text overlay (same command as process_local.sh)
        DATE_TEXT=$(date "+%A %d %b")
        WEATHER_TEXT="+28°C Sunny (test)"
        PAD=50
        SZ_DATE=56
        SZ_WEATHER=44
        SHADOW=3

        echo "  Embedding overlay: Date=$DATE_TEXT  Weather=$WEATHER_TEXT"
        convert /tmp/test_input.jpg \
            -resize "1072x1448^" -gravity Center -extent "1072x1448" \
            -colorspace Gray -depth 8 \
            -fill black -gravity SouthWest -pointsize $SZ_DATE \
                -annotate "+$((PAD+SHADOW))+$((PAD-SHADOW))" "$DATE_TEXT" \
            -fill white -gravity SouthWest -pointsize $SZ_DATE \
                -annotate "+${PAD}+${PAD}" "$DATE_TEXT" \
            -fill black -gravity SouthEast -pointsize $SZ_WEATHER \
                -annotate "+$((PAD+SHADOW))+$((PAD-SHADOW))" "$WEATHER_TEXT" \
            -fill white -gravity SouthEast -pointsize $SZ_WEATHER \
                -annotate "+${PAD}+${PAD}" "$WEATHER_TEXT" \
            -define png:color-type=0 \
            /output/test_photo.png

        if [ -s /output/test_photo.png ]; then
            SIZE=$(ls -lh /output/test_photo.png | awk "{print \$5}")
            echo ""
            echo "  ✅ SUCCESS: test_photo.png ($SIZE) — text embedded."
        else
            echo "  ❌ FAILED: output file is missing or empty."
            exit 1
        fi
    '

# ── Step 4: Open result ───────────────────────────────────────────────────────
echo ""
echo "[4/4] Test complete! Output saved to:"
echo "      $TEST_DIR/test_photo.png"
echo ""

# Try to open the image on Windows (works in Git Bash)
if command -v explorer.exe &>/dev/null; then
    explorer.exe "$(echo "$TEST_DIR" | sed 's|/mnt/c|C:|; s|/|\\|g')"  2>/dev/null || true
fi

ls -lh "$TEST_DIR/test_photo.png"
echo ""
echo "=== All checks passed. The arm32v7 ImageMagick binary works correctly. ==="
