#!/bin/sh
# status.sh - Check OnlineScreensaver state

# Function to log to screen
screen_log() {
    eips 0 $1 "$2"
    echo "$2"
}

# load configuration
if [ -e "config.sh" ]; then
    source ./config.sh
fi

eips -c
screen_log 0 "OS Status Check v$VERSION"

# 1. Check Mount
if grep -q "/usr/share/blanket/screensaver" /proc/mounts; then
    screen_log 1 "Mount: OK"
else
    screen_log 1 "Mount: MISSING"
fi

# 2. Check Extension Scheduler
if ps auxww | grep "scheduler.sh" | grep -qv grep; then
    screen_log 2 "Scheduler: RUNNING"
else
    screen_log 2 "Scheduler: STOPPED"
fi

# 3. Check Log File
LOGFILE="/mnt/us/extensions/onlinescreensaver/logs/onlinescreensaver.txt"
if [ -f "$LOGFILE" ]; then
    screen_log 3 "Log: CREATED ($(du -h "$LOGFILE" | awk '{print $1}'))"
else
    screen_log 3 "Log: MISSING"
fi

# 4. Check Upstart Configs
if [ -f /etc/upstart/onlinescreensaver-mount.conf ]; then
    screen_log 4 "Upstart Job: INSTALLED"
else
    screen_log 4 "Upstart Job: MISSING"
fi

# 5. Check Permissions & Folder
if [ -d "/mnt/us/extensions/onlinescreensaver" ]; then
    screen_log 5 "Ext Folder: EXISTS"
    if [ -w "/mnt/us/extensions/onlinescreensaver/logs" ]; then
        screen_log 6 "Logs Folder: WRITABLE"
    else
        screen_log 6 "Logs Folder: NOT WRITABLE"
    fi
else
    screen_log 5 "Ext Folder: MISSING"
fi

# 6. Check Mount Contents
if [ -d "/usr/share/blanket/screensaver" ]; then
    SC_COUNT=$(ls /usr/share/blanket/screensaver/*.png 2>/dev/null | wc -l)
    screen_log 7 "Mount Files: $SC_COUNT"
    if [ $SC_COUNT -eq 0 ]; then
        screen_log 8 "!! NO IMAGES IN MOUNT !!"
    fi
fi

screen_log 9 "Press any key/button to exit."
