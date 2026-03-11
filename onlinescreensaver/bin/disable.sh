#!/bin/sh
#
# Disable the online screensaver auto-update.

# Change to directory of this script
cd "$(dirname "$0")"

# Load configuration
if [ -e "config.sh" ]; then
	source ./config.sh
fi

# Load utils
if [ -e "utils.sh" ]; then
	source ./utils.sh
else
	echo "Could not find utils.sh in $(pwd)"
	exit 1
fi

logger "Disabling online screensaver auto-update"

# Kill the scheduler process if running
PID=$(ps xa | grep "scheduler.sh" | grep -v grep | awk '{ print $1 }')
if [ -n "$PID" ]; then
	logger "Killing scheduler process: $PID"
	kill $PID || true
else
	logger "No running scheduler process found"
fi

# Remove the upstart config if present
if [ -e /etc/upstart/onlinescreensaver.conf ]; then
	mntroot rw
	rm /etc/upstart/onlinescreensaver.conf
	mntroot ro
	logger "Removed upstart job"
fi

# Remove enabled flag if present
if [ -e /mnt/us/extensions/onlinescreensaver/enabled ]; then
	rm /mnt/us/extensions/onlinescreensaver/enabled
fi

logger "Auto-update disabled."
