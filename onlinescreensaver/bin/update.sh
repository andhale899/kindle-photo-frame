#!/bin/sh
#
##############################################################################
#
# Fetch weather screensaver from a configurable URL.

# change to directory of this script
cd "$(dirname "$0")"

# load configuration
if [ -e "config.sh" ]; then
	source ./config.sh
fi

# Ensure basic defaults if config is missing or partial
[ -z "$LOGFILE" ] && LOGFILE="/mnt/us/extensions/onlinescreensaver/logs/onlinescreensaver.txt"
[ -z "$TMPFILE" ] && TMPFILE="/tmp/tmp.onlinescreensaver.png"
[ -z "$LOGGING" ] && LOGGING=1

# Function to log to file and system log
log() {
    # Ensure log directory exists just in case
    mkdir -p "$(dirname "$LOGFILE")"
    echo "$(date) : $1" >> "$LOGFILE"
    logger "$1"
}

# load utils
if [ -e "utils.sh" ]; then
	source ./utils.sh
else
    # Fallback log if utils.sh is missing
    mkdir -p "$(dirname "$LOGFILE")"
    echo "$(date) : Error: utils.sh not found" >> "$LOGFILE"
	exit 1
fi

# Fetch system status
BATT=$(powerd_test -s | grep "Battery Level" | awk '{print $3}')
# ensure sleep is inhibited
toggle_inhibit 1

# v2.0 TURBO RADIO IGNITION
WIFI_STATE=$(lipc-get-prop com.lab126.cmd wirelessEnable)
logger "v2.0 Check: WiFi state is $WIFI_STATE"

# FORCE Airplane Mode OFF (in case it got stuck)
lipc-set-prop com.lab126.cmd airplaneMode 0 2>/dev/null

if [ "$WIFI_STATE" -eq 0 ]; then
	logger "WiFi is off, forcing ignition"
	lipc-set-prop com.lab126.cmd wirelessEnable 1
	DISABLE_WIFI=1
    sleep 5
fi

# wait for network to be up
TIMER=${NETWORK_TIMEOUT}
CONNECTED=0
KICKED=0
TURBO_THRESHOLD=20 # Reset radio early if it's stubborn

if [ "$RUN_MODE" = "dev" ]; then
    eips 0 38 "WiFi: Searching... (v$VERSION)"
fi

while [ 0 -eq $CONNECTED ]; do
	# test whether we can ping outside
	/bin/ping -c 1 $TEST_DOMAIN > /dev/null && CONNECTED=1

	if [ 0 -eq $CONNECTED ]; then
		TIMER=$(($TIMER-1))
		
        # TURBO RESET: If we've waited 20s and still nothing, force-restart the radio
        if [ $(( $NETWORK_TIMEOUT - $TIMER )) -ge $TURBO_THRESHOLD ] && [ $KICKED -eq 0 ]; then
            logger "TURBO RESET: Stubborn radio detected. Cycling WiFi power..."
            if [ "$RUN_MODE" = "dev" ]; then eips 0 38 "WiFi: Stubborn radio... Cycling!"; fi
            lipc-set-prop com.lab126.cmd wirelessEnable 0
            sleep 3
            lipc-set-prop com.lab126.cmd wirelessEnable 1
            KICKED=1
        fi

        # TURBO REASSOCIATE & SCAN: Every 10s, force the radio to look and join
        if [ $(( $TIMER % 10 )) -eq 0 ]; then
            logger "Turbo Scan/Sync: Checking Radio Health... ($TIMER s)"
            
            # 1. Check Physical Interface
            IP=$(/sbin/ifconfig wlan0 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}')
            
            # 2. Check Kindle Connection Manager State
            KSTATE=$(lipc-get-prop com.lab126.wifid cmState 2>/dev/null)
            
            # 3. Force Scan for visibility
            /usr/bin/wpa_cli -i wlan0 scan >/dev/null 2>&1
            sleep 2
            SSIDS=$(/usr/bin/wpa_cli -i wlan0 scan_results | awk -F'\t' '/[0-9a-f]{2:}/{print $5}' | tr '\n' ',' | sed 's/,$//')
            
            logger "Diagnostic: IP=[${IP:-none}] State=[$KSTATE] SSIDs=[${SSIDS:-none}]"
            
            /usr/bin/wpa_cli -i wlan0 reassociate >/dev/null 2>&1
            if [ "$RUN_MODE" = "dev" ]; then eips 0 38 "WiFi: $KSTATE... ($TIMER s)"; fi
        fi

		if [ 0 -eq $TIMER ]; then
			log "No internet/DNS connection after ${NETWORK_TIMEOUT} seconds, aborting."
            if [ "$RUN_MODE" = "dev" ]; then
                eips -f -g /usr/share/blanket/screensaver/bg_ss00.png 2>/dev/null
                eips 0 38 "!!! WIFI FAILED (v$VERSION) !!!"
            fi
			break
		fi
        # Periodic on-screen heartbeat
        if [ $(( $TIMER % 10 )) -eq 0 ] && [ "$RUN_MODE" = "dev" ]; then
            eips 0 38 "WiFi: Still waiting... ($TIMER s)"
        fi
		sleep 1
	fi
done

if [ 1 -eq $CONNECTED ]; then
    # ONLY log the start once we have internet to avoid Telegram timeouts
    # We use eips to show progress on screen
    eips 0 0 "Updating Screen v$VERSION... (Batt: $BATT)"
    log "--- Update Started v$VERSION (Battery: $BATT) ---" "dev_only"

	if curl -kl $IMAGE_URI -o $TMPFILE; then
		mkdir -p $(dirname $SCREENSAVERFILE)
		mv -f $TMPFILE $SCREENSAVERFILE
		
		# Kindle framework often looks for various prefixed/numbered files
		# We'll populate a wider range to cover all Kindle models
		for i in 00 01 02 03 04 05 06 07 08 09 10; do
			cp "$SCREENSAVERFILE" "$(dirname "$SCREENSAVERFILE")/bg_ss$i.png"
			cp "$SCREENSAVERFILE" "$(dirname "$SCREENSAVERFILE")/bg_xsmall_ss$i.png"
			cp "$SCREENSAVERFILE" "$(dirname "$SCREENSAVERFILE")/bg_medium_ss$i.png"
			cp "$SCREENSAVERFILE" "$(dirname "$SCREENSAVERFILE")/bg_large_ss$i.png"
		done
		
		log "Screen saver image file updated v$VERSION (cloned 00-10)" "success"
                # refresh screen if in screensaver mode
                lipc-get-prop com.lab126.powerd status | grep "Screen Saver" && (
                     log "Updating image on screen via eips" "dev_only"
                     eips -f -g $SCREENSAVERFILE
                     
                     # Force framework to reload screensaver (PW3 specific)
                     log "Force-reloading screensaver framework..." "dev_only"
                     lipc-set-prop com.lab126.blanket unload 1 2>/dev/null
                     lipc-set-prop com.lab126.blanket load 1 2>/dev/null
                     
                     batt=`powerd_test -s | awk -F: '/Battery Level: / {print $2}' | awk -F' |%' '{print $2}'`
# Create json for POST
generate_post_data()
{
  cat<<EOF
{
  "kindle_battery":"$batt"
}
EOF
}
                     # If WEBHOOKADR has been defined, send data
					 if [ "" != $WEBHOOKADR ]; then
                       curl -X POST -k -d "$(generate_post_data)" -H 'Content-Type: application/json' $WEBHOOKADR
                     fi
                     eips 40 39 "Batt:${batt}%"
                )
	else
		log "Error downloading image: $(tail -n 1 $LOGFILE)"
		if [ 1 -eq $DONOTRETRY ]; then
			touch $SCREENSAVERFILE
		fi
	fi
fi

# release suspension inhibitor
toggle_inhibit 0

# disable wireless if necessary
if [ 1 -eq $DISABLE_WIFI ]; then
	log "Disabling WiFi"
	lipc-set-prop com.lab126.cmd wirelessEnable 0
fi

exit 0
