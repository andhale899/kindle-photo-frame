#############################################################################
### ONLINE-SCREENSAVER CONFIGURATION SETTINGS
### Configured for Kindle Paperwhite 7th Gen
#############################################################################

# Interval in MINUTES in which to update the screensaver by default.
# Used when no schedule entry matches.
DEFAULTINTERVAL=60

# Schedule for updating the screensaver.
# Format: "STARTHOUR:STARTMINUTE-ENDHOUR:ENDMINUTE=INTERVAL_IN_MINUTES"
SCHEDULE="00:00-06:00=240 06:00-23:00=30 23:00-24:00=240"

# Forced interval (optional). If set, this overrides the schedule.
# Set via KUAL menu (e.g., 5, 10, 60). Leave empty to use SCHEDULE.
FORCE_INTERVAL=

# --- GitHub Repository Settings ---
# Where to fetch processed photos from
REPO_USER="andhale899"
REPO_NAME="kindle-photo-frame"
REPO_BRANCH="processed-photos"
REPO_PATH="photos"

# Folder that holds the screensavers (linkss screensaver hack folder)
SCREENSAVERFOLDER=/mnt/us/linkss/screensavers/

# Screensaver file format to overwrite.
# We will use sequential naming: bg_ss01.png, bg_ss02.png, etc.
SCREENSAVERNAME=bg_ss

# Whether to create log output (1) or not (0)
LOGGING=1

# Where to log to (relative to this bin folder)
LOGFILE=../onlinescreensaver.log

# Whether to disable WiFi after the script has finished
# (if WiFi was off when script started, it will always turn it off)
DISABLE_WIFI=0

# Domain to ping to test network connectivity
TEST_DOMAIN="www.google.com"

# How long (in seconds) to wait for internet connection to be established
NETWORK_TIMEOUT=30

#############################################################################
# Advanced
#############################################################################

# The real-time clock to use (0, 1 or 2)
# RTC=1 is required for Kindle Paperwhite / Touch
RTC=1

# Temporary file to download the screensaver image to
TMPFILE=/tmp/tmp.onlinescreensaver.png

# Webhook address for battery reporting (leave empty to disable)
WEBHOOKADR=""
