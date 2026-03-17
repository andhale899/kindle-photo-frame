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

# Fetch battery percentage at start
batt_percent=$(powerd_test -s | grep "Battery Level" | awk '{print $3}' | tr -d '%')
log "--- Update Started v$VERSION (Battery: $batt_percent%) ---"

# --- v4.5 POWER GUARDIAN ---
BATT_ALERT_FILE="/tmp/last_batt_threshold"

# 1. Check for Emergency Pause
if [ "$batt_percent" -le "$BATT_PAUSE" ]; then
    log "CRITICAL: Battery at $batt_percent% (Threshold: $BATT_PAUSE%). Pausing updates to save power." "error"
    send_telegram_msg "🔋 CRITICAL: Battery at $batt_percent%. OnlineScreensaver is now PAUSED until charged."
    exit 0
fi

# 2. Check for Alerts
for threshold in $BATT_ALERTS; do
    if [ "$batt_percent" -le "$threshold" ]; then
        LAST_SENT=$(cat "$BATT_ALERT_FILE" 2>/dev/null || echo 100)
        if [ "$threshold" -lt "$LAST_SENT" ]; then
            log "POWER: Battery dropped below $threshold%." "dev_only"
            send_telegram_msg "🔌 LOW BATTERY: Kindle at $batt_percent% (Alert Threshold: $threshold%)."
            echo "$threshold" > "$BATT_ALERT_FILE"
        fi
        break # Only fire for the highest met threshold
    fi
done

# Reset threshold tracker if battery is charging (higher than alerts)
FIRST_ALERT=$(echo $BATT_ALERTS | awk '{print $1}')
if [ "$batt_percent" -gt "$FIRST_ALERT" ]; then
    rm -f "$BATT_ALERT_FILE"
fi

# ensure sleep is inhibited
toggle_inhibit 1

# v2.0 TURBO RADIO IGNITION
WIFI_STATE=$(lipc-get-prop com.lab126.cmd wirelessEnable)
logger "v2.0 Check: WiFi state is $WIFI_STATE"

# FORCE Airplane Mode OFF (in case it got stuck)
lipc-set-prop com.lab126.cmd airplaneMode 0 2>/dev/null

if [ -n "$WIFI_STATE" ] && [ "$WIFI_STATE" -eq 0 ] 2>/dev/null; then
	logger "WiFi is off, forcing ignition"
	lipc-set-prop com.lab126.cmd wirelessEnable 1
	SHOULD_DISABLE_WIFI=1
    sleep 5
fi

# wait for network to be up
TIMER=${NETWORK_TIMEOUT}
CONNECTED=0
KICKED=0
TURBO_THRESHOLD=20 # Reset radio early if it's stubborn

# 3-Strike Rule Implementation
STRIKE_FILE="/tmp/wifi_strike_count"
STRIKES=$(cat "$STRIKE_FILE" 2>/dev/null || echo 0)
PASSIVE_MODE=0
if [ "$STRIKES" -ge 3 ]; then
    logger "3-STRIKE RULE: Consecutive failures: $STRIKES. Entering PASSIVE battery mode."
    PASSIVE_MODE=1
fi

if [ "$RUN_MODE" = "dev" ]; then
    eips 0 38 "WiFi: Searching... (v$VERSION)"
fi

SSIDS=""
SLEDGEHAMMER_FIRED=0

while [ 0 -eq $CONNECTED ]; do
    # PASSIVE MODE RECOVERY PROBE (v4.5.5)
    # If in passive mode, allow a connection attempt once every ~100 cycles (approx 24h at 15m intervals)
    if [ "$PASSIVE_MODE" -eq 1 ]; then
        PROBE_FILE="/tmp/passive_probe_count"
        PROBE_COUNT=$(cat "$PROBE_FILE" 2>/dev/null || echo 0)
        PROBE_COUNT=$((PROBE_COUNT + 1))
        
        if [ "$PROBE_COUNT" -gt 100 ]; then
            log "PASSIVE MODE PROBE: Attempting daily recovery ping..." "dev_only"
            rm -f "$PROBE_FILE" # Reset counter for next time
            # Do NOT break; fall through to the ping attempt below
        else
            echo "$PROBE_COUNT" > "$PROBE_FILE"
            log "PASSIVE MODE ACTIVE: Skipping network checks (Probe in $(( 100 - PROBE_COUNT )) cycles)." "dev_only"
            break
        fi
    fi

	# test whether we can ping outside
	if /bin/ping -c 1 -w 2 $TEST_DOMAIN > /dev/null 2>&1; then
        CONNECTED=1
        TELEGRAM_READY=1
        # If we connected, ensure we aren't trapped in passive mode anymore
        if [ "$PASSIVE_MODE" -eq 1 ]; then
            log "RECOVERY SUCCESS: Network restored. Clearing strikes." "success"
            rm -f "$STRIKE_FILE"
            PASSIVE_MODE=0
        fi
    fi

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
            
            # 3. Aggressive Framework Kick (Skip if in Passive Mode)
            if [ "$PASSIVE_MODE" -eq 0 ]; then
                lipc-set-prop com.lab126.wifid scan 1 2>/dev/null
                lipc-set-prop com.lab126.cmd ensureConnection "any" 2>/dev/null
            fi
            
            # 4. POLITE SLEDGEHAMMER (Wait 60s, then check for idle state)
            # Skip if Passive or if User is Active
            if [ "$PASSIVE_MODE" -eq 0 ] && [ $(( $NETWORK_TIMEOUT - $TIMER )) -ge 60 ] && [ -z "$IP" ] && [ "$SSIDS" = "" ] && [ "$SLEDGEHAMMER_FIRED" -eq 0 ]; then
                # Check Power State
                PSTATE_RAW=$(lipc-get-prop com.lab126.powerd status | grep "Powerd state")
                case "$PSTATE_RAW" in
                    *"Screen Saver"*|*"Ready to Suspend"*|*"Ready"*)
                        logger "SLEDGEHAMMER: Radio is ZOMBIE. Simulating Power Button Press..."
                        if [ "$RUN_MODE" = "dev" ]; then eips 0 38 "!!! SLEDGEHAMMER WAKE !!!"; fi
                        powerd_test -p 2>/dev/null
                        SLEDGEHAMMER_FIRED=1
                        sleep 5
                        ;;
                    *)
                        logger "Sledgehammer SKIPPED: Polite mode (User is Active: $PSTATE_RAW)"
                        ;;
                esac
            fi
            
            # 5. Low-level Scan for visibility (Skip if Passive)
            if [ "$PASSIVE_MODE" -eq 0 ]; then
                /usr/bin/wpa_cli -i wlan0 scan >/dev/null 2>&1
                sleep 2
                SSIDS=$(/usr/bin/wpa_cli -i wlan0 scan_results | awk -F'\t' '/[0-9a-f]{2:}/{print $5}' | tr '\n' ',' | sed 's/,$//')
            fi
            
            logger "Diagnostic: IP=[${IP:-none}] State=[$KSTATE] SSIDs=[${SSIDS:-none}] Strikes=[$STRIKES]"
            
            if [ "$PASSIVE_MODE" -eq 0 ]; then
                /usr/bin/wpa_cli -i wlan0 reassociate >/dev/null 2>&1
            fi
            
            if [ "$RUN_MODE" = "dev" ]; then eips 0 38 "WiFi: $KSTATE... ($TIMER s)"; fi
        fi

		if [ 0 -eq $TIMER ]; then
			log "No internet/DNS connection after ${NETWORK_TIMEOUT} seconds, aborting."
            
            # Strike Rule: Increment count
            NEW_STRIKES=$(( $STRIKES + 1 ))
            echo "$NEW_STRIKES" > "$STRIKE_FILE"
            logger "WiFi strike recorded: $NEW_STRIKES"

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

# --- v3.0 THE CAROUSEL LOGIC ---

# 1. Sync Vault: Download all 15 images from GitHub
sync_vault() {
    log "CAROUSEL: Syncing Vault (Target: $VAULT_COUNT images)..." "dev_only"
    mkdir -p "$VAULT_DIR"
    
    SUCCESS_COUNT=0
    i=1
    while [ $i -le $VAULT_COUNT ]; do
        idx=$(pad_index $i)
        VIMAGE="$VAULT_DIR/photo_$idx.png"
        VURL="$IMAGE_BASE_URL/photo_$idx.png"
        
        # Download if net is up (max 30s per photo)
        if curl -klL --connect-timeout 10 -m 30 "$VURL" -o "$TMPFILE"; then
            mv -f "$TMPFILE" "$VIMAGE"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        else
            log "CAROUSEL: Failed to sync photo_$idx" "dev_only"
        fi
        i=$((i + 1))
    done
    log "CAROUSEL: Sync Complete ($SUCCESS_COUNT/$VAULT_COUNT synced)." "success"
}

# 2. Rotate Carousel: Fill SS slots with a variety from the Vault
rotate_carousel() {
    # State file to track next image index
    STATE_FILE="/tmp/carousel_next_idx"
    [ -e "$STATE_FILE" ] || echo "1" > "$STATE_FILE"
    NEXT_IDX=$(cat "$STATE_FILE")
    
    log "CAROUSEL: Preparing Multi-Slot rotation starting at #$NEXT_IDX..." "dev_only"
    
    mkdir -p $(dirname "$SCREENSAVERFILE")
    
    # Fill the Kindle slots with the full range from the vault
    # This ensures that even if you lock/unlock many times, you see different photos!
    # We loop from 0 to VAULT_COUNT - 1
    i=0
    while [ $i -lt $VAULT_COUNT ]; do
        # Calculate index for this slot (looping 1-VAULT_COUNT)
        SLOT_IDX=$(( (NEXT_IDX + i - 1) % VAULT_COUNT + 1 ))
        PADDED_V_IDX=$(pad_index $SLOT_IDX)
        PADDED_S_IDX=$(pad_index $i)
        
        SOURCE_IMAGE="$VAULT_DIR/photo_$PADDED_V_IDX.png"
        
        if [ -f "$SOURCE_IMAGE" ]; then
            # Main file (slot 00 is usually the primary)
            [ $i -eq 0 ] && cp -f "$SOURCE_IMAGE" "$SCREENSAVERFILE"
            
            # Framework slots
            TGT_DIR=$(dirname "$SCREENSAVERFILE")
            cp -f "$SOURCE_IMAGE" "$TGT_DIR/bg_ss$PADDED_S_IDX.png"
            cp -f "$SOURCE_IMAGE" "$TGT_DIR/bg_xsmall_ss$PADDED_S_IDX.png"
            cp -f "$SOURCE_IMAGE" "$TGT_DIR/bg_medium_ss$PADDED_S_IDX.png"
            cp -f "$SOURCE_IMAGE" "$TGT_DIR/bg_large_ss$PADDED_S_IDX.png"
        fi
        i=$((i + 1))
    done

    # Increment global pointer for the next 15-minute shift
    NEW_IDX=$((NEXT_IDX + 1))
    [ $NEW_IDX -gt $VAULT_COUNT ] && NEW_IDX=1
    echo "$NEW_IDX" > "$STATE_FILE"
    
    # Trigger Refresh if in screensaver mode
    lipc-get-prop com.lab126.powerd status | grep "Screen Saver" && (
         eips -f -g "$SCREENSAVERFILE"
         lipc-set-prop com.lab126.blanket unload 1 2>/dev/null
         lipc-set-prop com.lab126.blanket load 1 2>/dev/null
         
         # Extract battery for overlay (dev mode only)
         if [ "$RUN_MODE" = "dev" ]; then
             batt=$(powerd_test -s | grep "Battery Level" | awk '{print $3}' | tr -d '%')
             eips 40 39 "Batt:${batt}% (v$VERSION)"
         fi
    )
    return 0
}

# --- Execution Flow ---

if [ 1 -eq $CONNECTED ]; then
    # Net is up: Sync the library
    sync_vault
fi

# Always rotate even if network failed/was skipped
rotate_carousel

# re-suspend logic (v2.8 Sleepwalker)
# If Sledgehammer was used to wake the radio, and the user hasn't interacted,
# fire it again to toggle the device back to screensaver/sleep.
if [ "$SLEDGEHAMMER_FIRED" -eq 1 ]; then
    # Double check power state before nuclear re-suspend
    PSTATE_FINAL=$(lipc-get-prop com.lab126.powerd status | grep "Powerd state")
    case "$PSTATE_FINAL" in
        *"Active"*)
            logger "SLEEPWALKER: Automatic Re-suspend triggered (v2.8)."
            if [ "$RUN_MODE" = "dev" ]; then eips 0 38 "--- RE-SUSPENDING ---"; fi
            sleep 5 # Final grace period
            powerd_test -p 2>/dev/null
            ;;
        *)
            logger "Sleepwalker SKIPPED: Device is already in $PSTATE_FINAL."
            ;;
    esac
fi

# disable wireless if necessary
if [ "${SHOULD_DISABLE_WIFI:-0}" -eq 1 ]; then
	log "Disabling WiFi"
	lipc-set-prop com.lab126.cmd wirelessEnable 0
fi

# release sleep inhibit
toggle_inhibit 0

exit 0
