##############################################################################
# Logs a message to the configured log file

logger () {
	MSG=$1
	
	# do nothing if logging is not enabled
	if [ "x1" != "x$LOGGING" ]; then
		return
	fi

	# if no logfile is specified, set a default
	if [ -z $LOGFILE ]; then
		LOGFILE=/dev/stderr
	fi

	echo `date`: $MSG >> $LOGFILE
}


##############################################################################
# Retrieves the current time in seconds

currentTime () {
	date +%s
}


##############################################################################
# Sets an RTC alarm to wake the Kindle at the right time
# arguments: $1 - amount of seconds to wake up in

set_rtc_wakeup()
{
	lipc-set-prop -i com.lab126.powerd rtcWakeup $1 2>&1
	logger "rtcWakeup has been set to $1"
}


##############################################################################
# Waits (using Kindle power events) for a given number of seconds.
# Properly sets RTC alarm when device suspends, so it wakes up on time.
# arguments: $1 - time in seconds to wait

wait_for () {
	ENDWAIT=$(( $(currentTime) + $1 ))
	REMAININGWAITTIME=$(( $ENDWAIT - $(currentTime) ))
	logger "Starting to wait for timeout to expire: $1 seconds"

	while [ $REMAININGWAITTIME -gt 0 ]; do
		EVENT=$(lipc-wait-event -s $1 com.lab126.powerd readyToSuspend,wakeupFromSuspend,resuming)
		REMAININGWAITTIME=$(( $ENDWAIT - $(currentTime) ))
		logger "Received event: $EVENT"

		case "$EVENT" in
			readyToSuspend*)
				set_rtc_wakeup $REMAININGWAITTIME
			;;
			wakeupFromSuspend*|resuming*)
				logger "Finishing the wait"
				break
			;;
			*)
				logger "Ignored event: $EVENT"
			;;
		esac
	done

	logger "Wait finished"
}
