#!/bin/sh
# Scripts to download and install the latest ZIP securely from GitHub
# This is triggered via the KUAL menu.

# Change to the bin directory
cd "$(dirname "$0")"

# Output function to screen
screen_log() {
    eips 0 "$1" "$2"
    echo "$2"
}

eips -c
screen_log 2 "OnlineScreensaver Auto-Updater"
screen_log 3 "Checking for latest release..."

# 1. Download Latest ZIP directly from GitHub Releases
URL="https://github.com/andhale899/kindle-photo-frame/releases/latest/download/KindlePhotoFrame_5.0-local.zip"
TMP_ZIP="/tmp/kpf_install.zip"

screen_log 5 "Downloading latest package..."
curl -k -L --connect-timeout 10 -o "$TMP_ZIP" "$URL"
if [ ! -s "$TMP_ZIP" ]; then
    screen_log 7 "ERROR: Download failed. Check WiFi."
    sleep 3
    exit 1
fi

screen_log 7 "Download complete. Extracting..."

# 2. Extract over existing files in /mnt/us
unzip -o "$TMP_ZIP" -d /mnt/us/ > /tmp/kpf_unzip.log 2>&1
if [ $? -ne 0 ]; then
    screen_log 9 "ERROR: Extraction failed."
    sleep 3
    exit 1
fi

# 3. Fix Line Endings
screen_log 9 "Fixing permissions and endings..."
for f in /mnt/us/extensions/onlinescreensaver/bin/*.sh; do
    sed -i 's/\r$//' "$f"
    chmod +x "$f"
done
chmod +x /mnt/us/extensions/onlinescreensaver/bin/convert 2>/dev/null || true
chmod +x /mnt/us/extensions/onlinescreensaver/bin/rtcwake 2>/dev/null || true
chmod +x /mnt/us/extensions/onlinescreensaver/bin/libs/ld-musl-armhf.so.1 2>/dev/null || true

# 4. Re-install upstart jobs
screen_log 11 "Updating system services..."
sh /mnt/us/extensions/onlinescreensaver/bin/install.sh quiet

screen_log 13 "UPDATE COMPLETE!"
screen_log 15 "The new version has been installed."
screen_log 16 "The KUAL extension is now running on the latest code."
sleep 4
