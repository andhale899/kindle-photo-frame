#!/bin/sh
# onlinescreensaver uninstall script

# Function to log to screen
screen_log() {
    eips 0 0 "$1"
    echo "$1"
}

eips -c
screen_log "Uninstalling OnlineScreensaver..."

# 1. Remount root filesystem as read-write
screen_log "Remounting root RW..."
mntroot rw

# 2. Stop and remove upstart jobs
screen_log "Removing upstart jobs..."
stop onlinescreensaver || true
stop onlinescreensaver-mount || true

rm -f /etc/upstart/onlinescreensaver.conf
rm -f /etc/upstart/onlinescreensaver-mount.conf

# 3. Unmount the screensaver directory if it's currently bind-mounted
KINDLE_SS_DIR="/usr/share/blanket/screensaver"
if grep -q "^fsp $KINDLE_SS_DIR" /proc/mounts; then
    screen_log "Unmounting bind mount..."
    umount -l "$KINDLE_SS_DIR"
fi

# 4. Remount root filesystem as read-only
mntroot ro

screen_log "Uninstallation complete. Rebooting now..."
sleep 5
reboot
