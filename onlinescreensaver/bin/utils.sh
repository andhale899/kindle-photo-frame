# Send a message to Telegram
send_telegram_msg() {
    if [ "${TELEGRAM_READY:-0}" -ne 1 ]; then
        return 1
    fi
    if [ "$ENABLE_TELEGRAM" -eq 1 ] && [ -n "$TELEGRAM_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
        # Check for network with a bit of patience
        # DNS often takes longer than IP ping. We check for $TEST_DOMAIN.
        TIMER=${NETWORK_TIMEOUT:-30}
        while [ $TIMER -gt 0 ]; do
             # Try to resolve a domain to ensure DNS is ready
            if /bin/ping -c 1 google.com > /dev/null 2>&1 || /bin/ping -c 1 8.8.8.8 > /dev/null 2>&1; then
                TIMER=999 # success flag
                break
            fi
            sleep 2
            TIMER=$((TIMER - 2))
        done

        if [ $TIMER -ne 999 ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S %Z') : Skipping Telegram (No Internet/DNS)" >> "$LOGFILE"
            return 1
        fi

        # Capture curl output (removed -s to see errors)
        CURL_OUT=$(curl -k --connect-timeout 15 \
            -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
            -d "chat_id=${TELEGRAM_CHAT_ID}" \
            --data-urlencode "text=$1" 2>&1)
        
    RET=$?
    if [ $RET -ne 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S %Z') : TELEGRAM ERROR ($RET): $CURL_OUT" >> "$LOGFILE"
    else
        echo "Telegram Message Sent Successfully."
    fi
  fi
}

toggle_inhibit() {
    # 1 to inhibit, 0 to release
    if [ "$1" -eq 1 ]; then
        logger "Inhibiting suspension for 120s..."
        lipc-set-prop -i com.lab126.powerd deferSuspend 120 2>/dev/null
    else
        logger "Releasing suspension inhibit."
        lipc-set-prop -i com.lab126.powerd deferSuspend 1 2>/dev/null
    fi
}

# Main logging function (File + Telegram)
# Helper for 0-padding numbers (e.g. 1 -> 01)
pad_index() {
    if [ "$1" -lt 10 ]; then
        echo "0$1"
    else
        echo "$1"
    fi
}

log() {
	MSG=$1
    LOG_TYPE=$2 # Optional: success, error, dev_only
    
    # Echo to console for SSH visibility
    echo "[LOG] $MSG"

	# do nothing if logging is not enabled
	if [ "x1" != "x$LOGGING" ]; then
		return
	fi

	# Ensure logfile path
	[ -z "$LOGFILE" ] && LOGFILE="/mnt/us/extensions/onlinescreensaver/logs/onlinescreensaver.txt"
    
    mkdir -p "$(dirname "$LOGFILE")"
    
    if [ $(stat -c%s "$LOGFILE" 2>/dev/null || echo 0) -gt 512000 ]; then
        mv "$LOGFILE" "${LOGFILE}.old"
    fi

	echo "$(date '+%Y-%m-%d %H:%M:%S %Z') [v$VERSION]: $MSG" >> "$LOGFILE"

    # Telegram Alerting Logic
    if [ "$ENABLE_TELEGRAM" -eq 1 ]; then
        if [ "$RUN_MODE" = "dev" ]; then
            send_telegram_msg "🛠️ [v$VERSION] $MSG"
        elif [ "$RUN_MODE" = "prod" ]; then
            if [ "$LOG_TYPE" = "success" ]; then
                send_telegram_msg "🖼️ [v$VERSION] $MSG"
            elif [ "$LOG_TYPE" = "error" ]; then
                send_telegram_msg "⚠️ [v$VERSION] ERROR: $MSG"
            fi
        fi
    fi
}

# Internal Chatty Logger (File ONLY - no Telegram)
logger() {
    [ -z "$LOGFILE" ] && LOGFILE="/mnt/us/extensions/onlinescreensaver/logs/onlinescreensaver.txt"
    mkdir -p "$(dirname "$LOGFILE")"
    
    if [ $(stat -c%s "$LOGFILE" 2>/dev/null || echo 0) -gt 512000 ]; then
        mv "$LOGFILE" "${LOGFILE}.old"
    fi

    echo "$(date '+%Y-%m-%d %H:%M:%S %Z') [v$VERSION-L]: $1" >> "$LOGFILE"
}


##############################################################################
# Retrieves the current time in seconds

currentTime () {
	date +%s
}


##############################################################################
# sets an RTC alarm
# arguments: $1 - time in seconds from now

#wait_for () { 
#	delay=$1
#	now=$(currentTime)
#
#        if [ "x1" == "x$LOGGING" ]; then
#		state=`/usr/bin/powerd_test -s | grep "Powerd state"`
#		defer=`/usr/bin/powerd_test -s | grep defer`
#		remain=`/usr/bin/powerd_test -s | grep Remain`
#		batt=`/usr/bin/powerd_test -s | grep Battery`
#		logger "wait_for called with $delay, now=$now, $state, $defer, $remain, $batt"
#	fi		
#	# calculate the time we should return
#	ENDWAIT=$(( $(currentTime) + $1 ))
#
#	# wait for timeout to expire
#	logger "Wait_for $1 seconds"
#	while [ $(currentTime) -lt $ENDWAIT ]; do
#		REMAININGWAITTIME=$(( $ENDWAIT - $(currentTime) ))
#		if [ 0 -lt $REMAININGWAITTIME ]; then
#			sleep 2
#			lipc-get-prop com.lab126.powerd status | grep "Screen Saver" 
#			if [ $? -eq 0 ]
#			then
#				# in screensaver mode
#				logger "go to sleep for $REMAININGWAITTIME seconds, wlan off"
#				lipc-set-prop com.lab126.cmd wirelessEnable 0
#				/mnt/us/extensions/onlinescreensaver/bin/rtcwake -d rtc$RTC -s $REMAININGWAITTIME -m mem
#				logger "woke up again"
#				logger "Finished waiting, switch wireless back on"
#				lipc-set-prop com.lab126.cmd wirelessEnable 1
#			else
#				# not in screensaver mode - don't really sleep with rtcwake
#				sleep $REMAININGWAITTIME
#			fi
#		fi
#	done
#

#	# not sure whether this is required
#	lipc-set-prop com.lab126.powerd -i deferSuspend 40
#	
#}

# runs when in the readyToSuspend state;
# sets the rtc to wake up
# arguments: $1 - amount of seconds to wake up in
set_rtc_wakeup()
{
	lipc-set-prop -i com.lab126.powerd rtcWakeup $1 2>&1
	logger "rtcWakeup has been set to $1"
}

##############################################################################
# sets an RTC alarm
# arguments: $1 - time in seconds from now

wait_for () {
	ENDWAIT=$(( $(currentTime) + $1 ))
	REMAININGWAITTIME=$(( $ENDWAIT - $(currentTime) ))
	logger "Starting to wait for timeout to expire: $1"

	# wait for timeout to expire
	while [ $REMAININGWAITTIME -gt 0 ]; do
        logger "wait_for: checking events (timeout $REMAININGWAITTIME)..."
		EVENT=$(lipc-wait-event -s $REMAININGWAITTIME com.lab126.powerd readyToSuspend,wakeupFromSuspend,resuming)
		REMAININGWAITTIME=$(( $ENDWAIT - $(currentTime) ))
		logger "wait_for: received event '$EVENT'"

		case "$EVENT" in
			readyToSuspend*)
				set_rtc_wakeup $REMAININGWAITTIME
			;;
			wakeupFromSuspend*|resuming*)
				logger "wait_for: woke up from suspend, breaking loop"
				break
			;;
			*)
				# If we timed out or got an ignored event
                if [ -z "$EVENT" ]; then
                    logger "wait_for: timed out naturally"
                fi
			;;
		esac
	done

	logger "wait_for: finished"
}
