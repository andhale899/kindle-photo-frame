#!/bin/sh
##############################################################################
# set_config.sh — Generic config value writer
# Usage: sh set_config.sh KEY VALUE
# Writes/updates KEY=VALUE in config.sh
##############################################################################

cd "$(dirname "$0")"

KEY="$1"
VALUE="$2"
CONFIG_FILE="config.sh"

if [ -z "$KEY" ] || [ -z "$VALUE" ]; then
    echo "Usage: set_config.sh KEY VALUE"
    exit 1
fi

if grep -q "^${KEY}=" "$CONFIG_FILE" 2>/dev/null; then
    # Update existing line
    sed -i "s|^${KEY}=.*|${KEY}=\"${VALUE}\"|" "$CONFIG_FILE"
else
    # Append new line
    echo "${KEY}=\"${VALUE}\"" >> "$CONFIG_FILE"
fi

echo "Config updated: ${KEY}=\"${VALUE}\""
logger "CONFIG: Set ${KEY}=\"${VALUE}\""
