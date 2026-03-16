#!/bin/sh
#
# Manual log cleanup script for OnlineScreensaver (v4.5)
# Prunes logs older than the configured threshold in config.sh

# change to directory of this script
cd "$(dirname "$0")"

# load configuration
if [ -e "config.sh" ]; then
	source ./config.sh
fi

# Ensure basic defaults
[ -z "$LOGFILE" ] && LOGFILE="/mnt/us/extensions/onlinescreensaver/logs/onlinescreensaver.txt"
[ -z "$LOG_RETENTION_DAYS" ] && LOG_RETENTION_DAYS=100

# Function to log local result
log_result() {
    echo "$(date) : $1" >> "$LOGFILE"
    echo "$1"
}

log_result "CLEANUP: Starting manual log pruning (Retention: $LOG_RETENTION_DAYS days)..."

# Prune .txt and rotated .old files
# -mtime +N means strictly older than N days
LOG_DIR=$(dirname "$LOGFILE")
find "$LOG_DIR" -maxdepth 1 -name "*.txt*" -mtime +$LOG_RETENTION_DAYS -exec rm -v {} \; > /tmp/cleanup_result.txt 2>&1

COUNT=$(grep -c "removed" /tmp/cleanup_result.txt || echo 0)

log_result "CLEANUP: Procedure complete. Removed $COUNT old log files."

# Clean up status file so the automatic (daily) one doesn't run if it were still there
rm -f "/tmp/log_archived_today"

exit 0
