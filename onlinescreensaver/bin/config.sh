#############################################################################
### ONLINE-SCREENSAVER CONFIGURATION SETTINGS (v5.0-local)
### Branch: kindle-local-only-main
### All processing happens ON the Kindle — no GitHub Actions needed.
#############################################################################

VERSION="5.0-local"

#############################################################################
# Photo Source (Google Photos shared album)
#############################################################################
ALBUM_URL="https://photos.app.goo.gl/yBPwxSGuEEnwnhGk9"
PHOTO_COUNT=15         # How many random photos to fetch per cycle

#############################################################################
# Kindle screen dimensions
#############################################################################
KINDLE_W=1072
KINDLE_H=1448

#############################################################################
# Weather overlay
#############################################################################
ENABLE_WEATHER=1
WEATHER_LOCATION="Ahmednagar, IN"   # "City, Country" format
WEATHER_UNITS="C"                   # C or F

#############################################################################
# ImageMagick path (auto-detected by setup.sh, override here if needed)
#############################################################################
CONVERT_BIN="convert"              # Will be updated to local path if installed
NO_OVERLAY=0                       # Set to 1 to disable overlay (no ImageMagick)

#############################################################################
# Scheduling
#############################################################################
DEFAULTINTERVAL=30                 # Minutes between updates

# Schedule range (used by checkschedule.sh)
SCHEDULE="00:00-24:00=30"

# Early Bird: wake this many seconds early for WiFi warmup
# (30m interval - 60s early = 29min actual sleep)

#############################################################################
# Passive Mode Config (v4.5.6)
#############################################################################
PROBE_INTERVAL_CYCLES=4    # Re-check network every 4 cycles (~2h at 30m)
PROBE_TIMEOUT=20           # Seconds to wait during passive probe

#############################################################################
# Vault (local image cache on Kindle)
#############################################################################
VAULT_DIR="/mnt/us/extensions/onlinescreensaver/vault"

#############################################################################
# Screensaver output paths
#############################################################################
SCREENSAVERFOLDER=/mnt/us/onlinescreensaver/screensaver
SCREENSAVERFILE=$SCREENSAVERFOLDER/bg_ss.png

#############################################################################
# Logging
#############################################################################
LOGGING=1
LOGFILE=/mnt/us/extensions/onlinescreensaver/logs/onlinescreensaver.txt
LOG_RETENTION_DAYS=30
RUN_MODE="prod"           # dev = verbose Telegram, prod = success/error only

#############################################################################
# Temp files
#############################################################################
URLS_FILE="/tmp/kindle_image_urls.txt"
TMPFILE=/tmp/tmp.onlinescreensaver.png

#############################################################################
# WiFi settings
#############################################################################
TEST_DOMAIN="www.google.com"
NETWORK_TIMEOUT=180

#############################################################################
# Telegram Alerts (credentials in secrets.sh)
#############################################################################
ENABLE_TELEGRAM=1

#############################################################################
# Battery Guardian (v4.5)
#############################################################################
BATT_ALERTS="40 35 30"
BATT_PAUSE=25

#############################################################################
# Advanced
#############################################################################
RTC=1
WEBHOOKADR=""

# Load secrets (gitignored)
[ -e "secrets.sh" ] && source ./secrets.sh
[ -e "/mnt/us/extensions/onlinescreensaver/bin/secrets.sh" ] && source /mnt/us/extensions/onlinescreensaver/bin/secrets.sh