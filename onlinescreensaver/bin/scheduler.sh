#!/bin/sh
#
##############################################################################
#
# Fetch weather screensaver from a configurable URL at configurable intervals.
#
# Features:
#   - updates even when device is suspended
#   - refreshes screensaver image if active
#   - turns WiFi on and back off if necessary
#   - tries to use as little CPU as possible
#
##############################################################################

# change to directory of this script
cd "$(dirname "$0")"

# load configuration
if [ -e "config.sh" ]; then
	source ./config.sh
else
	# set default values
	INTERVAL=240
	RTC=0
fi

# load utils
if [ -e "utils.sh" ]; then
	source ./utils.sh
else
	echo "Could not find utils.sh in `pwd`"
	exit
fi


###############################################################################

# create a two day filling schedule
extend_schedule () {
	SCHEDULE_ONE=""
	SCHEDULE_TWO=""

	LASTENDHOUR=0
	LASTENDMINUTE=0
	LASTEND=0
	for schedule in $SCHEDULE; do
		read STARTHOUR STARTMINUTE ENDHOUR ENDMINUTE THISINTERVAL << EOF
			$( echo " $schedule" | sed -e 's/[:,=,\,,-]/ /g' -e 's/\([^0-9]\)0\([[:digit:]]\)/\1\2/g')
EOF
		START=$(( 60*$STARTHOUR + $STARTMINUTE ))
		END=$(( 60*$ENDHOUR + $ENDMINUTE ))

		# if the previous schedule entry ended before this one starts,
		# create a filler
		if [ $LASTEND -lt $START ]; then
			SCHEDULE_ONE="$SCHEDULE_ONE $LASTENDHOUR:$LASTENDMINUTE-$STARTHOUR:$STARTMINUTE=$DEFAULTINTERVAL"
			SCHEDULE_TWO="$SCHEDULE_TWO $(($LASTENDHOUR+24)):$LASTENDMINUTE-$(($STARTHOUR+24)):$STARTMINUTE=$DEFAULTINTERVAL"
		fi
		SCHEDULE_ONE="$SCHEDULE_ONE $schedule"
		SCHEDULE_TWO="$SCHEDULE_TWO $(($STARTHOUR+24)):$STARTMINUTE-$(($ENDHOUR+24)):$ENDMINUTE=$THISINTERVAL"
		
		LASTENDHOUR=$ENDHOUR
		LASTENDMINUTE=$ENDMINUTE
		LASTEND=$END
	done

	# check that the schedule goes to midnight
	if [ $LASTEND -lt $(( 24*60 )) ]; then
		SCHEDULE_ONE="$SCHEDULE_ONE $LASTENDHOUR:$LASTENDMINUTE-24:00=$DEFAULTINTERVAL"
		SCHEDULE_TWO="$SCHEDULE_TWO $(($LASTENDHOUR+24)):$LASTENDMINUTE-48:00=$DEFAULTINTERVAL"
	fi
	
	# to handle the day overlap, append the schedule again for hours 24-48.
	SCHEDULE="$SCHEDULE_ONE $SCHEDULE_TWO"
	logger "Full two day schedule: $SCHEDULE"
}


##############################################################################

# return number of minutes until next update
get_time_to_next_update () {
	CURRENTMINUTE=$(( 60*$(date +%-H) + $(date +%-M) ))

	for schedule in $SCHEDULE; do
		read STARTHOUR STARTMINUTE ENDHOUR ENDMINUTE INTERVAL << EOF
			$( echo " $schedule" | sed -e 's/[:,=,\,,-]/ /g' -e 's/\([^0-9]\)0\([[:digit:]]\)/\1\2/g' )
EOF
		START=$(( 60*$STARTHOUR + $STARTMINUTE ))
		END=$(( 60*$ENDHOUR + $ENDMINUTE ))

		# ignore schedule entries that end prior to the current time
		if [ $CURRENTMINUTE -gt $END ]; then
			continue

		# if this schedule entry covers the current time, use it
		elif [ $CURRENTMINUTE -ge $START ] && [ $CURRENTMINUTE -lt $END ]; then
			logger "Schedule $schedule used, next update in $INTERVAL minutes"
			NEXTUPDATE=$(( $CURRENTMINUTE + $INTERVAL))

		# if the next update falls into (or overlaps) a following schedule
		# entry, apply this schedule entry instead if it would trigger earlier
		elif [ -n "$NEXTUPDATE" ] && [ $(( $START + $INTERVAL )) -lt $NEXTUPDATE ]; then
			logger "Selected timeout will overlap $schedule, applying it instead"
			NEXTUPDATE=$(( $START + $INTERVAL ))
		fi
	done

	# Handle case where NEXTUPDATE was never set
	[ -z "$NEXTUPDATE" ] && NEXTUPDATE=$(( CURRENTMINUTE + DEFAULTINTERVAL ))

	logger "Next update in $(( $NEXTUPDATE - $CURRENTMINUTE )) minutes"
	echo $(( $NEXTUPDATE - $CURRENTMINUTE ))
}


##############################################################################

# use a 48 hour schedule
extend_schedule

# forever and ever, try to update the screensaver
while [ 1 -eq 1 ]; do 
    logger "--- Background Loop Start ---"
	sh ./update.sh
    logger "--- Heartbeat: Update Cycle Complete v$VERSION ---"
	
	# wait for the next trigger time
    # v2.0 EARLY BIRD WAKEUP: Wake up 60s early to allow WiFi and hardware to "warm up"
    # This ensures we are connected and ready to download EXACTLY at the 5-minute mark.
    WAIT_TIME=$(( 60 * $(get_time_to_next_update) ))
    if [ $WAIT_TIME -gt 120 ]; then
        EARLY_WAIT=$(( $WAIT_TIME - 60 ))
        logger "Early Bird: Waking 60s early ($EARLY_WAIT s) for WiFi warmup."
        wait_for $EARLY_WAIT
    else
        logger "Interval too short for Early Bird, waiting full $WAIT_TIME s."
        wait_for $WAIT_TIME
    fi
    logger "Background scheduler woke up from wait."
done
