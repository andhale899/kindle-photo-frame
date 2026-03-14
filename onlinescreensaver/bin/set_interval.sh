#!/bin/sh
# set_interval.sh <minutes>

cd "$(dirname "$0")"
INTERVAL=$1
CONFIG="./config.sh"

# Load config and utils if they exist locally
[ -f "./config.sh" ] && source ./config.sh
[ -f "./utils.sh" ] && source ./utils.sh

# Function to log to screen AND file
screen_log() {
    eips 0 0 "$1"
    echo "$1"
    if [ -n "$LOGFILE" ]; then
        mkdir -p "$(dirname "$LOGFILE")"
        echo "$(date '+%Y-%m-%d %H:%M:%S %Z') : $1" >> "$LOGFILE"
    fi
    logger "INTERVAL: $1"
}

if [ -z "$INTERVAL" ]; then
    screen_log "Error: No interval provided"
    exit 1
fi

eips -c
screen_log "Setting interval to $INTERVAL min..."

if [ ! -f "$CONFIG" ]; then
    screen_log "Error: config.sh not found at $CONFIG"
    exit 1
fi

# Update DEFAULTINTERVAL and clear SCHEDULE to ensure the new interval takes effect everywhere
# We use sed to replace the lines
if sed -i "s/^DEFAULTINTERVAL=.*/DEFAULTINTERVAL=$INTERVAL/" "$CONFIG" && \
   sed -i 's/^SCHEDULE=.*/SCHEDULE=""/' "$CONFIG"; then
    screen_log "Configuration updated."
else
    screen_log "Error: Failed to update config.sh"
    exit 1
fi

# Restart service to apply changes
screen_log "Restarting service..."
if [ -f /etc/upstart/onlinescreensaver.conf ]; then
    stop onlinescreensaver || true
    
    # Retry loop for starting service (Bug 8)
    RETRY=0
    STARTED=0
    while [ $RETRY -lt 3 ]; do
        sleep 2
        if start onlinescreensaver; then
            STARTED=1
            break
        fi
        RETRY=$((RETRY + 1))
        screen_log "Retry start ($RETRY/3)..."
    done

    if [ $STARTED -eq 1 ]; then
        screen_log "Done! Next update in $INTERVAL min."
    else
        screen_log "Error: Failed to start service."
    fi
else
    screen_log "Error: Standalone not installed."
    screen_log "Run 'Install Standalone' first."
fi
