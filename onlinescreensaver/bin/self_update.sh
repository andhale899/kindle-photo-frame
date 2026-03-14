#!/bin/sh
# self_update.sh (v4.0 The Phoenix)
# 
# This script allows the Kindle to update its own screensaver extension
# by pulling the latest code directly from GitHub.

cd "$(dirname "$0")"
source ./config.sh
source ./utils.sh

REPO_URL="https://github.com/andhale899/kindle-photo-frame/archive/refs/heads/master.zip"
TMP_ZIP="/tmp/kindle-photo-frame-master.zip"
EXT_ROOT="/mnt/us/extensions/onlinescreensaver"

log "PHOENIX: Starting Remote Self-Update..." "dev_only"
eips 0 38 "Update: Starting... (v$VERSION)"

# 1. Wake WiFi (Turbo)
eips 0 38 "Update: Waking WiFi..."
lipc-set-prop com.lab126.cmd airplaneMode 0 2>/dev/null
lipc-set-prop com.lab126.cmd wirelessEnable 1
sleep 10

# 2. Check Connection
if ! /bin/ping -c 1 www.google.com > /dev/null; then
    log "PHOENIX: Update FAILED. No internet connection." "error"
    eips 0 38 "!!! UPDATE FAILED: NO WIFI !!!"
    exit 1
fi

# 3. Download Latest Zip
log "PHOENIX: Downloading latest source from GitHub..." "dev_only"
eips 0 38 "Update: Downloading zip..."
if ! curl -Lk "$REPO_URL" -o "$TMP_ZIP"; then
    log "PHOENIX: Download FAILED." "error"
    eips 0 38 "!!! UPDATE FAILED: DOWNLOAD ERR !!!"
    exit 1
fi

# 4. Unpack
log "PHOENIX: Unpacking update..." "dev_only"
eips 0 38 "Update: Unpacking..."
unzip -o "$TMP_ZIP" -d /tmp/

# 5. Protective Deployment
# We keep secrets.sh!
log "PHOENIX: Deploying files (preserving secrets)..." "dev_only"
eips 0 38 "Update: Deploying..."
cp -r /tmp/kindle-photo-frame-master/onlinescreensaver/* "$EXT_ROOT/"

# Cleanup
rm -rf /tmp/kindle-photo-frame-master
rm -f "$TMP_ZIP"

# 6. Post-update cleanup (fixing line endings just in case)
sed -i 's/\r$//' "$EXT_ROOT/bin/"*.sh
chmod +x "$EXT_ROOT/bin/"*.sh

log "PHOENIX: Self-Update SUCCESSFUL! System rebooting in 5s..." "success"
eips 0 38 "PHOENIX: SUCCESS! REBOOTING..."
sleep 5
/usr/bin/reboot
