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

# 1. Get the list of photos from the GitHub repository
logger "Fetching photo list from GitHub repository: $REPO_USER/$REPO_NAME ($REPO_BRANCH)"
REPO_API_URL="https://api.github.com/repos/${REPO_USER}/${REPO_NAME}/contents/${REPO_PATH}?ref=${REPO_BRANCH}"

PHOTO_LIST=$(curl -s -k "$REPO_API_URL" | grep '"download_url":' | sed -E 's/.*"download_url": "([^"]+)".*/\1/')

if [ -z "$PHOTO_LIST" ]; then
	logger "No photos found in the repository or error fetching list."
	exit 1
fi

# 2. Enable wireless if it is currently off
if [ 0 -eq $(lipc-get-prop com.lab126.cmd wirelessEnable) ]; then
	logger "WiFi is off, turning it on now"
	lipc-set-prop com.lab126.cmd wirelessEnable 1
	DISABLE_WIFI=1
fi

# 3. Wait for network to be up
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
	logger "Network connected. Downloading photos..."
	
	# Clear existing screensavers in the folder to avoid stale images
	# Only delete files matching our pattern
	rm -f "$SCREENSAVERFOLDER/${SCREENSAVERNAME}"*.png

	COUNT=1
	for PHOTO_URL in $PHOTO_LIST; do
		# Format the filename with leading zero (e.g. 01, 02)
		SUFFIX=$(printf "%02d" $COUNT)
		TARGET_FILE="$SCREENSAVERFOLDER/${SCREENSAVERNAME}${SUFFIX}.png"
		
		logger "Downloading image $COUNT: $TARGET_FILE"
		
		if curl -L -k --max-time 30 "$PHOTO_URL" -o "$TMPFILE"; then
			cp "$TMPFILE" "$TARGET_FILE"
			rm "$TMPFILE"
			logger "Success."
		else
			logger "Error: failed to download $PHOTO_URL"
		fi
		
		COUNT=$((COUNT+1))
	done

	# If the screensaver is currently active, refresh screen with the first image
	FIRST_SS="$SCREENSAVERFOLDER/${SCREENSAVERNAME}01.png"
	if [ -e "$FIRST_SS" ]; then
		lipc-get-prop com.lab126.powerd status | grep "Screen Saver" && (
			logger "Screensaver is active — refreshing screen with $FIRST_SS"
			eips -f -g "$FIRST_SS"

			# Show battery on screen
			batt=$(powerd_test -s | awk -F: '/Battery Level: / {print $2}' | awk -F' |%' '{print $2}')
			eips 40 39 "Batt:${batt}%"
		)
	fi
fi

# 4. Disable wireless if we turned it on
if [ 1 -eq $DISABLE_WIFI ]; then
	logger "Disabling WiFi"
	lipc-set-prop com.lab126.cmd wirelessEnable 0
fi

logger "Done."
