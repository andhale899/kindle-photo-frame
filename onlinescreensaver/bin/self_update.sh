#!/bin/sh
# self_update.sh (v4.0 The Phoenix)
# 
# This script allows the Kindle to update its own screensaver extension
# by pulling the latest code directly from GitHub.

cd "$(dirname "$0")"
source ./config.sh
source ./utils.sh

REPO_URL="https://github.com/andhale899/kindle-photo-frame/archive/refs/heads/master.zip"
TMP_ZIP="/tmp/update.zip"
EXT_ROOT="/mnt/us/extensions/onlinescreensaver"

log "PHOENIX: Starting Remote Self-Update..." "dev_only"
eips 0 38 "Update: Starting... (v$VERSION)"

# 1. Wake WiFi (Turbo)
eips 0 38 "Update: Waking WiFi..."
lipc-set-prop com.lab126.cmd airplaneMode 0 2>/dev/null
lipc-set-prop com.lab126.cmd wirelessEnable 1
sleep 10

# 2. Check Connection (with retries)
MAX_RETRIES=6
RETRY_COUNT=0
CONNECTED=0

log "PHOENIX: Waiting for internet connection..." "dev_only"
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -s --head  --request GET https://www.google.com | grep "200 OK" > /dev/null; then
        CONNECTED=1
        break
    fi
    log "PHOENIX: No internet, retrying in 10s... ($RETRY_COUNT/$MAX_RETRIES)" "dev_only"
    eips 0 38 "Update: Waiting for WiFi ($RETRY_COUNT)..."
    RETRY_COUNT=$((RETRY_COUNT+1))
    sleep 10
done

if [ $CONNECTED -eq 0 ]; then
    log "PHOENIX: Update FAILED. No internet connection." "error"
    eips 0 38 "!!! UPDATE FAILED: NO WIFI !!!"
    exit 1
fi

# 3. Download Latest Zip
log "PHOENIX: Downloading latest source from GitHub..." "dev_only"
eips 0 38 "Update: Downloading zip..."
rm -f "$TMP_ZIP"
if ! curl -Lk "$REPO_URL" -o "$TMP_ZIP"; then
    log "PHOENIX: Download FAILED." "error"
    eips 0 38 "!!! UPDATE FAILED: DOWNLOAD ERR !!!"
    exit 1
fi

# Log size for debugging
if [ -f "$TMP_ZIP" ]; then
    SIZE=$(ls -l "$TMP_ZIP" | awk '{print $5}')
    log "PHOENIX: Downloaded $SIZE bytes." "dev_only"
    if [ "$SIZE" -lt 1000 ]; then
        log "PHOENIX: Downloaded file too small. Likely error page." "error"
        eips 0 38 "!!! UPDATE FAILED: ZIP TOO SMALL !!!"
        exit 1
    fi
fi

# 4. Unpack
log "PHOENIX: Unpacking update..." "dev_only"
eips 0 38 "Update: Unpacking..."
rm -rf /tmp/kindle-photo-frame-*
# Simplified unzip for maximum compatibility (removed trailing slash on -d)
if ! unzip -o "$TMP_ZIP" -d /tmp; then
    log "PHOENIX: Unzip FAILED." "error"
    eips 0 38 "!!! UPDATE FAILED: UNZIP ERR !!!"
    exit 1
fi

# 5. Protective Deployment (Dynamic Path Detection)
log "PHOENIX: Deploying files..." "dev_only"
eips 0 38 "Update: Deploying..."

# Find the unpacked directory (GitHub zips are repo-name-branch or repo-name-master)
UPD_DIR=$(ls -d /tmp/kindle-photo-frame-* 2>/dev/null | grep -v "\.zip$" | head -n 1)

if [ -z "$UPD_DIR" ]; then
    log "PHOENIX: Could not find update source directory." "error"
    exit 1
fi

# Copy everything
cp -r "$UPD_DIR/onlinescreensaver/"* "$EXT_ROOT/"

# Cleanup
rm -rf "$UPD_DIR"
rm -f "$TMP_ZIP"

# 6. Post-update cleanup (fixing line endings)
# CRITICAL: We skip active/running scripts to avoid hanging the process on BusyBox
log "PHOENIX: Finalizing permissions..." "dev_only"
for f in "$EXT_ROOT/bin/"*.sh; do
    FNAME=$(basename "$f")
    case "$FNAME" in
        "self_update.sh"|"scheduler.sh"|"update.sh") 
            log "PHOENIX: Skipping busy script: $FNAME" "dev_only"
            chmod +x "$f"
            continue 
            ;;
        *) 
            log "PHOENIX: Processing $FNAME..." "dev_only"
            sed -i 's/\r$//' "$f"
            chmod +x "$f"
            ;;
    esac
done

log "PHOENIX: Self-Update SUCCESSFUL! System rebooting in 5s..." "success"
eips 0 38 "PHOENIX: SUCCESS! REBOOTING..."
sleep 5
/usr/bin/reboot
