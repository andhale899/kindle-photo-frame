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

# 1. Prevent the Kindle from sleeping while we are working
# This is critical to ensure the network stays active
lipc-set-prop com.lab126.powerd preventScreenSaver 1

# 2. Enable wireless if it is currently off
if [ 0 -eq $(lipc-get-prop com.lab126.cmd wirelessEnable) ]; then
	logger "WiFi is off, turning it on now"
	lipc-set-prop com.lab126.cmd wirelessEnable 1
	DISABLE_WIFI=1
fi

# 3. Wait for network to be up
TIMER=60 # Increased to 60s for better reliability on wake-up
CONNECTED=0
while [ 0 -eq $CONNECTED ]; do
	# Try to ping. If it fails, maybe nudge the wifi
	if /bin/ping -c 1 $TEST_DOMAIN > /dev/null; then
		CONNECTED=1
	else
		# Every 10 seconds, if not connected, try to nudge the wifi association
		if [ $(( $TIMER % 10 )) -eq 0 ]; then
			logger "Waiting for Wi-Fi... (${TIMER}s left)"
		fi
		
		TIMER=$(($TIMER-1))
		if [ 0 -eq $TIMER ]; then
			logger "No internet connection after 60 seconds, aborting."
			break
		else
			sleep 1
		fi
	fi
done

if [ 1 -eq $CONNECTED ]; then
	# 4. Get the list of photos from the GitHub repository
	logger "Fetching photo list from GitHub repository: $REPO_USER/$REPO_NAME ($REPO_BRANCH)"
	REPO_API_URL="https://api.github.com/repos/${REPO_USER}/${REPO_NAME}/contents/${REPO_PATH}?ref=${REPO_BRANCH}"

	# GitHub API requires a User-Agent. Adding -k for insecure/old Kindle certs.
	# Using -w to capture HTTP status code
	RAW_RESPONSE=$(curl -s -k -H "User-Agent: Kindle-Photo-Frame" "$REPO_API_URL")
	HTTP_STATUS=$(curl -s -k -H "User-Agent: Kindle-Photo-Frame" -o /dev/null -w "%{http_code}" "$REPO_API_URL")

	# Extract download_urls more robustly using grep -o and cut
	PHOTO_LIST=$(echo "$RAW_RESPONSE" | grep -o '"download_url":"[^"]*"' | cut -d'"' -f4)

	if [ -z "$PHOTO_LIST" ]; then
		logger "Error: No photos found. HTTP Status: $HTTP_STATUS. Response snippet: $(echo "$RAW_RESPONSE" | head -c 100)"
	else
		logger "Downloading photos..."
		
		# Clear existing screensavers in the folder to avoid stale images
		# Only delete files matching our pattern
		rm -f "$SCREENSAVERFOLDER/${SCREENSAVERNAME}"*.png

		COUNT=1
		# Clean up folder path (remove trailing slash if present to avoid //)
		CLEAN_FOLDER=$(echo "$SCREENSAVERFOLDER" | sed 's/\/$//')

		for PHOTO_URL in $PHOTO_LIST; do
			# Format the filename with leading zero (e.g. 01, 02)
			SUFFIX=$(printf "%02d" $COUNT)
			TARGET_FILE="$CLEAN_FOLDER/${SCREENSAVERNAME}${SUFFIX}.png"
			
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
		FIRST_SS="$CLEAN_FOLDER/${SCREENSAVERNAME}01.png"
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
fi

# 5. Restore default sleep behavior
lipc-set-prop com.lab126.powerd preventScreenSaver 0

# 6. Disable wireless if we turned it on
if [ 1 -eq $DISABLE_WIFI ]; then
	logger "Disabling WiFi"
	lipc-set-prop com.lab126.cmd wirelessEnable 0
fi

logger "Done."
