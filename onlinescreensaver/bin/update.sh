#!/bin/sh
#
##############################################################################
#
# Fetch screensaver image from the configured URL and update the Kindle screensaver.
#
# - Enables WiFi if off, waits for connection
# - Downloads image via curl to a temp file
# - Moves to the screensaver folder (linkss watches this)
# - If screen is currently showing a screensaver, refreshes it with eips

# Change to directory of this script
cd "$(dirname "$0")"

# Load configuration
if [ -e "config.sh" ]; then
	source ./config.sh
else
	TMPFILE=/tmp/tmp.onlinescreensaver.png
fi

# Load utils
if [ -e "utils.sh" ]; then
	source ./utils.sh
else
	echo "Could not find utils.sh in $(pwd)"
	exit 1
fi

# Do nothing if no URL is set
if [ -z "$IMAGE_URI" ]; then
	logger "No image URL has been set. Please edit config.sh."
	exit 1
fi

logger "Starting screensaver update from: $IMAGE_URI"

# Enable wireless if it is currently off
if [ 0 -eq $(lipc-get-prop com.lab126.cmd wirelessEnable) ]; then
	logger "WiFi is off, turning it on now"
	lipc-set-prop com.lab126.cmd wirelessEnable 1
	DISABLE_WIFI=1
fi

# Wait for network to be up
TIMER=${NETWORK_TIMEOUT}
CONNECTED=0
while [ 0 -eq $CONNECTED ]; do
	/bin/ping -c 1 $TEST_DOMAIN > /dev/null && CONNECTED=1

	if [ 0 -eq $CONNECTED ]; then
		TIMER=$(($TIMER-1))
		if [ 0 -eq $TIMER ]; then
			logger "No internet connection after ${NETWORK_TIMEOUT} seconds, aborting."
			break
		else
			sleep 1
		fi
	fi
done

if [ 1 -eq $CONNECTED ]; then
	logger "Network connected. Downloading image..."
	if curl -L -k --max-time 30 "$IMAGE_URI" -o "$TMPFILE"; then
		# Copy the file instead of moving to avoid ownership errors on FAT32
		cp "$TMPFILE" "$SCREENSAVERFILE"
		rm "$TMPFILE"
		
		logger "Screensaver image updated: $SCREENSAVERFILE"

		# If the screensaver is currently active, refresh it on screen right now
		lipc-get-prop com.lab126.powerd status | grep "Screen Saver" && (
			logger "Screensaver is active — refreshing screen with eips"
			eips -f -g "$SCREENSAVERFILE"

			# Optional: get battery level
			batt=$(powerd_test -s | awk -F: '/Battery Level: / {print $2}' | awk -F' |%' '{print $2}')

			# Send battery to webhook if configured
			if [ -n "$WEBHOOKADR" ] && [ "" != "$WEBHOOKADR" ]; then
				logger "Sending battery level ($batt%) to webhook"
				curl -X POST -k --max-time 10 \
					-d "{\"kindle_battery\":\"$batt\"}" \
					-H 'Content-Type: application/json' \
					"$WEBHOOKADR"
			fi

			# Show battery on screen (bottom corner)
			eips 40 39 "Batt:${batt}%"
		)
	else
		logger "Error: failed to download screensaver image from $IMAGE_URI"
	fi
fi

# Disable wireless if we turned it on
if [ 1 -eq $DISABLE_WIFI ]; then
	logger "Disabling WiFi"
	lipc-set-prop com.lab126.cmd wirelessEnable 0
fi

logger "Done."
