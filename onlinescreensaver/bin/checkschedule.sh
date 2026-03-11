#!/bin/sh
#
# Diagnostic script — prints the parsed schedule from config.sh
# and shows which entry is currently active.

# Change to directory of this script
cd "$(dirname "$0")"

# Load configuration
if [ -e "config.sh" ]; then
	source config.sh
fi

# Load utils
if [ -e "utils.sh" ]; then
	source utils.sh
else
	echo "Could not find utils.sh in $(pwd)"
	exit
fi

# Get current minute of the day
CURRENTMINUTE=$(( $(date +%-H)*60 + $(date +%-M) ))
echo "Current time: $(date +%H:%M)  ($CURRENTMINUTE minutes since midnight)"
echo ""

for schedule in $SCHEDULE; do
	echo "-------------------------------------------------------"
	echo "Parsing \"$schedule\""
	read STARTHOUR STARTMINUTE ENDHOUR ENDMINUTE INTERVAL << EOF
		$( echo " $schedule" | sed -e 's/[:,=,\,,-]/ /g' -e 's/\([^0-9]\)0\([[:digit:]]\)/\1\2/g' )
EOF
	echo "  Starts at $STARTHOUR:$(printf '%02d' $STARTMINUTE)"
	echo "  Ends at   $ENDHOUR:$(printf '%02d' $ENDMINUTE)"
	echo "  Interval: $INTERVAL minutes"

	START=$(( 60*$STARTHOUR + $STARTMINUTE ))
	END=$(( 60*$ENDHOUR + $ENDMINUTE ))

	if [ $END -lt $START ]; then
		echo "  !!!!!!! End time is before start time — fix your schedule!"
	fi

	if [ $CURRENTMINUTE -ge $START ] && [ $CURRENTMINUTE -lt $END ]; then
		echo "  --> ACTIVE (this schedule entry is currently in effect)"
	fi
done
echo "-------------------------------------------------------"
