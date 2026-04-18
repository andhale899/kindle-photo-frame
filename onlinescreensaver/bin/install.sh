#!/bin/sh
# onlinescreensaver install script

# Change to script directory
cd "$(dirname "$0")"
LOGFILE="/mnt/us/extensions/onlinescreensaver/logs/onlinescreensaver.txt"

# Load config and utils if they exist locally
[ -f "./config.sh" ] && source ./config.sh
[ -f "./utils.sh" ] && source ./utils.sh

# Function to log to screen AND file
screen_log() {
    ROW="$1"
    MSG="$2"
    eips 0 "$ROW" "$MSG"
    echo "$MSG"
    # Fallback log if utils.sh isn't loaded yet or fails
    if [ -n "$LOGFILE" ]; then
        mkdir -p "$(dirname "$LOGFILE")"
        echo "$(date) : $MSG" >> "$LOGFILE"
    fi
    logger "INSTALL: $MSG"
    
    # Send to Telegram if available
    if command -v send_telegram_msg > /dev/null; then
        send_telegram_msg "🛠️ [INSTALL] $MSG"
    fi
}

eips -c
screen_log 3 "Installing OnlineScreensaver..."

# Check for secrets
if [ ! -f "./secrets.sh" ]; then
    screen_log 5 "WARNING: secrets.sh not found!"
    screen_log 6 "Telegram will be disabled."
fi

# 1. Remount root filesystem as read-write
screen_log 8 "Remounting root RW..."
mntroot rw

# 2. Ensure directories exist
mkdir -p /mnt/us/onlinescreensaver/screensaver
mkdir -p /mnt/us/extensions/onlinescreensaver/logs # Unified logs location

# Cleanup old logs if they exist outside
[ -d /mnt/us/onlinescreensaver/logs ] && rm -rf /mnt/us/onlinescreensaver/logs

# 3. Copy upstart jobs
screen_log 10 "Copying upstart jobs..."
cp ./onlinescreensaver-mount.conf /etc/upstart/
cp ./onlinescreensaver.conf /etc/upstart/

# 4. Set permissions
screen_log 12 "Setting script permissions..."
chmod +x ./*.sh

# 5. Remount root filesystem as read-only
screen_log 14 "Remounting root RO..."
mntroot ro

if [ "$1" = "quiet" ]; then
    screen_log 16 "Install complete. Restarting services..."
    start onlinescreensaver-mount || true
    start onlinescreensaver || true
else
    screen_log 16 "Install complete. Rebooting now..."
    sleep 5
    reboot
fi
