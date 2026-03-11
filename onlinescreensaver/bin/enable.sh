#!/bin/sh
#
# Enable the online screensaver auto-update by installing the upstart job.

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

# Handle interval override from argument
INTERVAL=$1
if [ -n "$INTERVAL" ]; then
	logger "Setting forced interval to $INTERVAL minutes"
	sed -i "s/^FORCE_INTERVAL=.*/FORCE_INTERVAL=$INTERVAL/" config.sh
else
	logger "Clearing forced interval (using default schedule)"
	sed -i "s/^FORCE_INTERVAL=.*/FORCE_INTERVAL=/" config.sh
fi

if [ -e /etc/upstart ]; then
	logger "Enabling online screensaver auto-update (upstart)"

	mntroot rw
	cp onlinescreensaver.conf /etc/upstart/
	mntroot ro

	start onlinescreensaver
	logger "Upstart job started successfully"
else
	# Fallback for Kindles without upstart
	logger "No /etc/upstart found, using fallback startup"
	/bin/sh /mnt/us/extensions/onlinescreensaver/bin/scheduler.sh &
	touch /mnt/us/extensions/onlinescreensaver/enabled
	logger "Scheduler started in background (fallback mode)"
fi
