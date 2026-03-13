#!/bin/sh
# test_telegram.sh

cd "$(dirname "$0")"
if [ -f "./config.sh" ]; then source ./config.sh; fi
if [ -f "./utils.sh" ]; then source ./utils.sh; fi

# Function to log to screen AND file
screen_log() {
    eips 0 "$1" "$2"
    echo "$2"
    # Ensure log folder exists even if run pre-install
    mkdir -p "/mnt/us/extensions/onlinescreensaver/logs"
    echo "$(date) : $2" >> "/mnt/us/extensions/onlinescreensaver/logs/onlinescreensaver.txt"
}

eips -c
screen_log 0 "Testing Telegram..."

if [ -z "$TELEGRAM_TOKEN" ]; then
    screen_log 1 "Error: Token is empty"
    exit 1
fi

if [ -z "$TELEGRAM_CHAT_ID" ]; then
    screen_log 1 "Error: Chat ID is empty"
    screen_log 2 "Check config.sh"
    exit 1
fi

# enable wireless if it is currently off
if [ 0 -eq `lipc-get-prop com.lab126.cmd wirelessEnable` ]; then
	screen_log 3 "WiFi is off, turning it on..."
	lipc-set-prop com.lab126.cmd wirelessEnable 1
	DISABLE_WIFI=1
fi

# wait for network to be up
TIMER=30
CONNECTED=0
while [ 0 -eq $CONNECTED ]; do
	/bin/ping -c 1 www.google.com > /dev/null && CONNECTED=1
	if [ 0 -eq $CONNECTED ]; then
		TIMER=$(($TIMER-1))
		if [ 0 -eq $TIMER ]; then
			screen_log 4 "Error: No internet connection"
			break
		else
			sleep 1
		fi
	fi
done

if [ 1 -eq $CONNECTED ]; then
    screen_log 5 "Sending ping to Bot..."
    send_telegram_msg "🔔 [TEST] Kindle is online and connected! Mode: $RUN_MODE"
    screen_log 6 "Test Sent! Check Telegram."
    screen_log 7 "Mode: $RUN_MODE"
fi

# disable wireless if we turned it on
if [ 1 -eq $DISABLE_WIFI ]; then
	lipc-set-prop com.lab126.cmd wirelessEnable 0
fi
