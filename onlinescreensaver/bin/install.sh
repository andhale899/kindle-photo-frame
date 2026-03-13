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
    eips 0 0 "$1"
    echo "$1"
    # Fallback log if utils.sh isn't loaded yet or fails
    if [ -n "$LOGFILE" ]; then
        mkdir -p "$(dirname "$LOGFILE")"
        echo "$(date) : $1" >> "$LOGFILE"
    fi
    logger "INSTALL: $1"
    
    # Send to Telegram if available
    if command -v send_telegram_msg > /dev/null; then
        send_telegram_msg "🛠️ [INSTALL] $1"
    fi
}

eips -c
screen_log "Installing OnlineScreensaver..."

# Check for secrets
if [ ! -f "./secrets.sh" ]; then
    screen_log "WARNING: secrets.sh not found!"
    screen_log "Telegram will be disabled."
fi

# 1. Remount root filesystem as read-write
screen_log "Remounting root RW..."
mntroot rw

# 2. Ensure directories exist
mkdir -p /mnt/us/onlinescreensaver/screensaver
mkdir -p /mnt/us/extensions/onlinescreensaver/logs # Unified logs location

# Cleanup old logs if they exist outside
[ -d /mnt/us/onlinescreensaver/logs ] && rm -rf /mnt/us/onlinescreensaver/logs

# 3. Copy upstart jobs
screen_log "Copying upstart jobs..."
cp ./onlinescreensaver-mount.conf /etc/upstart/
cp ./onlinescreensaver.conf /etc/upstart/

# 4. Set permissions
chmod +x ./*.sh

# 5. Remount root filesystem as read-only
screen_log "Remounting root RO..."
mntroot ro

screen_log "Install complete. Rebooting now..."
sleep 5
reboot
