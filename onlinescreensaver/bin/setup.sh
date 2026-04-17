#!/bin/sh
##############################################################################
# setup.sh — First-run setup and self-check
# 
# This branch (kindle-local-only-main) has ZERO external dependencies:
#   - curl      → built into all Kindles
#   - eips      → built into all Kindles (text overlay on screen)
#   - grep/sed/awk → busybox, built into all Kindles
#   - No Python, no ImageMagick, no pip, no GitHub Actions
#
# This script just verifies the environment and sets up directories.
##############################################################################

cd "$(dirname "$0")"
[ -e "config.sh" ] && source ./config.sh
[ -e "utils.sh" ]  && source ./utils.sh

EXT_DIR="/mnt/us/extensions/onlinescreensaver"
LOG_DIR="$EXT_DIR/logs"
VAULT_DIR="${VAULT_DIR:-$EXT_DIR/vault}"
SS_DIR="${SCREENSAVERFOLDER:-/mnt/us/onlinescreensaver/screensaver}"

##############################################################################
# Ensure directories exist
##############################################################################
mkdir -p "$LOG_DIR"
mkdir -p "$VAULT_DIR"
mkdir -p "$SS_DIR"

##############################################################################
# Check required tools (all should be built-in)
##############################################################################
MISSING=""

command -v curl  >/dev/null 2>&1 || MISSING="$MISSING curl"
command -v grep  >/dev/null 2>&1 || MISSING="$MISSING grep"
command -v awk   >/dev/null 2>&1 || MISSING="$MISSING awk"
command -v eips  >/dev/null 2>&1 || MISSING="$MISSING eips"

if [ -n "$MISSING" ]; then
    log "SETUP: WARNING — Missing built-in tools:$MISSING" "error"
    log "SETUP: This should not happen on a standard jailbroken Kindle." "error"
else
    logger "SETUP: All required tools present (curl, grep, awk, eips). No dependencies to install."
fi

##############################################################################
# Validate config
##############################################################################
if [ -z "$ALBUM_URL" ]; then
    log "SETUP: WARNING — ALBUM_URL is not set in config.sh!" "error"
    log "SETUP: Open KUAL → Photo Frame → ⚙️ Settings → 📷 Photo Source to configure." "error"
fi

logger "SETUP: v$VERSION ready. Vault: $VAULT_DIR | Screensaver: $SS_DIR"
