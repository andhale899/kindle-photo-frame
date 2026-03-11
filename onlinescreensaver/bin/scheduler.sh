#!/bin/sh
#
##############################################################################
#
# Loops forever, calling update.sh at the interval defined in config.sh.
# Uses schedule-aware sleep via Kindle power events (RTC wakeup).

# Change to directory of this script
cd "$(dirname "$0")"

# Load configuration
if [ -e "config.sh" ]; then
	source ./config.sh
else
	DEFAULTINTERVAL=60
	RTC=1
fi

# Load utils
if [ -e "utils.sh" ]; then
	source ./utils.sh
else
	echo "Could not find utils.sh in $(pwd)"
	exit 1
fi


###############################################################################
# Build a full two-day schedule to handle day boundaries cleanly

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

	if [ $LASTEND -lt $(( 24*60 )) ]; then
		SCHEDULE_ONE="$SCHEDULE_ONE $LASTENDHOUR:$LASTENDMINUTE-24:00=$DEFAULTINTERVAL"
		SCHEDULE_TWO="$SCHEDULE_TWO $(($LASTENDHOUR+24)):$LASTENDMINUTE-48:00=$DEFAULTINTERVAL"
	fi
	
	SCHEDULE="$SCHEDULE_ONE $SCHEDULE_TWO"
	logger "Full two-day schedule: $SCHEDULE"
}


###############################################################################
# Returns the number of minutes until the next update

get_time_to_next_update () {
	CURRENTMINUTE=$(( 60*$(date +%-H) + $(date +%-M) ))

	for schedule in $SCHEDULE; do
		read STARTHOUR STARTMINUTE ENDHOUR ENDMINUTE INTERVAL << EOF
			$( echo " $schedule" | sed -e 's/[:,=,\,,-]/ /g' -e 's/\([^0-9]\)0\([[:digit:]]\)/\1\2/g' )
EOF
		START=$(( 60*$STARTHOUR + $STARTMINUTE ))
		END=$(( 60*$ENDHOUR + $ENDMINUTE ))

		if [ $CURRENTMINUTE -gt $END ]; then
			continue
		elif [ $CURRENTMINUTE -ge $START ] && [ $CURRENTMINUTE -lt $END ]; then
			logger "Schedule $schedule used, next update in $INTERVAL minutes"
			NEXTUPDATE=$(( $CURRENTMINUTE + $INTERVAL))
		elif [ $(( $START + $INTERVAL )) -lt $NEXTUPDATE ]; then
			logger "Selected timeout overlaps $schedule, applying it"
			NEXTUPDATE=$(( $START + $INTERVAL ))
		fi
	done

	WAITMINUTES=$(( $NEXTUPDATE - $CURRENTMINUTE ))
	logger "Next update in $WAITMINUTES minutes"
	echo $WAITMINUTES
}


###############################################################################

# Build two-day schedule
extend_schedule

logger "Scheduler started"

# Loop forever
while [ 1 -eq 1 ]; do
	sh ./update.sh
	
	# Wait until next scheduled update time
	if [ -n "$FORCE_INTERVAL" ] && [ "$FORCE_INTERVAL" -eq "$FORCE_INTERVAL" ] 2>/dev/null; then
		WAITMINUTES=$FORCE_INTERVAL
		logger "Forced interval active: next update in $WAITMINUTES minutes"
	else
		WAITMINUTES=$(get_time_to_next_update)
	fi
	
	logger "Sleeping for $WAITMINUTES minutes"
	wait_for $(( 60 * $WAITMINUTES ))
done
