#############################################################################
### ONLINE-SCREENSAVER CONFIGURATION SETTINGS
### Configured for Kindle Paperwhite 7th Gen
#############################################################################

# Interval in MINUTES in which to update the screensaver by default.
# Used when no schedule entry matches.
DEFAULTINTERVAL=60

# Schedule for updating the screensaver.
# Format: "STARTHOUR:STARTMINUTE-ENDHOUR:ENDMINUTE=INTERVAL_IN_MINUTES"
# Between midnight and 6am: update every 4 hours (save battery at night)
# Between 6am and 11pm: update every 30 minutes (stay fresh during the day)
# Between 11pm and midnight: update every 4 hours
SCHEDULE="00:00-06:00=240 06:00-23:00=30 23:00-24:00=240"

# URL of screensaver image.
# MUST be exact resolution of your Kindle screen (1072x1448 for Paperwhite 7)
# and MUST be a clean 8-bit grayscale PNG.
IMAGE_URI="https://raw.githubusercontent.com/andhale899/kindle-photo-frame/screensaver-deploy/screensaver.png"

# Folder that holds the screensavers (linkss screensaver hack folder)
SCREENSAVERFOLDER=/mnt/us/linkss/screensavers/

# Screensaver file to overwrite.
# Set to bg_ss00.png as requested
SCREENSAVERFILE=$SCREENSAVERFOLDER/bg_ss00.png

# Whether to create log output (1) or not (0)
LOGGING=1

# Where to log to (saved to extension folder for easy reading)
LOGFILE=/mnt/us/extensions/onlinescreensaver/onlinescreensaver.log

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
# Example for Home Assistant: "http://homeassistant.local/api/webhook/kindle-battery-update-hook"
WEBHOOKADR=""
