#!/bin/sh
# toggle_mode.sh

cd "$(dirname "$0")"
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
        echo "$(date) : $1" >> "$LOGFILE"
    fi
    logger "MODE: $1"
}

if [ ! -f "$CONFIG" ]; then
    screen_log "Error: config.sh not found"
    exit 1
fi

# Read current mode
CURRENT_MODE=$(grep "^RUN_MODE=" "$CONFIG" | cut -d'"' -f2)

if [ "$CURRENT_MODE" = "prod" ]; then
    NEW_MODE="dev"
else
    NEW_MODE="prod"
fi

# Update config.sh
sed -i "s/^RUN_MODE=.*/RUN_MODE=\"$NEW_MODE\"/" "$CONFIG"

eips -c
screen_log "Switched to $NEW_MODE mode."
screen_log "Dev: All logs to Telegram"
screen_log "Prod: Success/Error only"
