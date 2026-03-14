#############################################################################
### ONLINE-SCREENSAVER CONFIGURATION SETTINGS (v2.1-stable)
#############################################################################

# Interval in MINUTES
DEFAULTINTERVAL=15
VERSION="2.8-stable"

# load secrets if available (managed in gitignore)
[ -e "secrets.sh" ] && source ./secrets.sh
[ -e "/mnt/us/extensions/onlinescreensaver/bin/secrets.sh" ] && source /mnt/us/extensions/onlinescreensaver/bin/secrets.sh

# Schedule for updating the screensaver.
SCHEDULE="00:00-24:00=5"

# URL of screensaver image (MUST be PNG)
IMAGE_URI="https://raw.githubusercontent.com/andhale899/kindle-photo-frame/processed-photos/photos/photo_01.png"

# folder that holds the screensavers
SCREENSAVERFOLDER=/mnt/us/onlinescreensaver/screensaver
# In which file to store the downloaded image.
SCREENSAVERFILE=$SCREENSAVERFOLDER/bg_ss.png

# Logging configuration
LOGGING=1
LOGFILE=/mnt/us/extensions/onlinescreensaver/logs/onlinescreensaver.txt

# WiFi management
DISABLE_WIFI=0
TEST_DOMAIN="www.google.com"
NETWORK_TIMEOUT=180

#############################################################################
# Environment & Telegram Alerts
#############################################################################

# RUN_MODE: dev (verbose) or prod (success only)
RUN_MODE="dev"

# Telegram Bot Integration (Credentials in secrets.sh)
ENABLE_TELEGRAM=1

#############################################################################
# Advanced
#############################################################################

RTC=1
TMPFILE=/tmp/tmp.onlinescreensaver.png
WEBHOOKADR=""