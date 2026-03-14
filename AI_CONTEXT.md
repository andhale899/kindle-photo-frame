# AI Context & Project Deep Knowledge (v2.7)

This document serves as a "Brain Dump" for future AI assistants working on this repository. It explains the subtle, Kindle-specific behaviors and the hard-won fixes that are not obvious from the code alone.

## 🔋 Kindle Power & WiFi Behavior
- **Deep Sleep**: Kindles aggressively gate the WiFi radio when suspended. 
- **The "Zombie Radio" State**: In background mode (RTC wake), the `wlan0` interface may report as "UP" but it won't see any SSIDs (`SSIDS=[none]`).
- **Framework vs. Low-level**: Commands like `ifconfig` or `wpa_cli` often fail to wake the hardware. Framework commands (`lipc`) are required to "kick" the system managers.

## 🚀 Key Fixes (The "Why")

### 1. The Early Bird (scheduler.sh)
- **Why**: WiFi warm-up takes 10-30 seconds. If we wake up at exactly the update time, the connection often fails.
- **How**: We wake up 60s early to give the hardware time to handshake before the `update.sh` script starts the download.

### 2. Adrenaline Shot (update.sh)
- **Why**: Sometimes the Kindle Connection Manager (`wifid`) gets stuck.
- **How**: We use `lipc-set-prop com.lab126.wifid scan 1` and `ensureConnection` to force the high-level framework to look for WiFi.

### 3. The Sledgehammer (update.sh)
- **Why**: In some cases, only a user interaction (physical button press) wakes the high-power WiFi path.
- **How**: `powerd_test -p` simulates a physical power button click.
- **Polite Logic (v2.6)**: We now check `lipc-get-prop com.lab126.powerd status`. If the state is not "Screen Saver" (e.g., user is reading), we skip the Sledgehammer to avoid locking the screen.

### 4. The 3-Strike Rule (v2.6)
- **Why**: Constant aggressive searching drains battery if you are out of WiFi range for hours.
- **How**: We track consecutive failures in `/tmp/wifi_strike_count`. After 3 strikes, we enter **Passive Mode**, disabling Turbo/Sledgehammer until a connection is restored.

### 5. Stability & Robustness (v2.7)
- **Telegram Gating**: We enforce a strict `$TELEGRAM_READY=1` guard on notifications. Without it, the script triggers a 70+ message error storm during the "WiFi Zombie" state while `/wlan0` tries to resolve DNS.
- **Sledgehammer Limiting**: The Sledgehammer is extremely disruptive (`powerd_test -p` physically flashes the screen). We strictly limit it with `SLEDGEHAMMER_FIRED=1` so it can only ever trigger once per cycle. 
- **Log Rotation**: We rotate `/mnt/us/extensions/onlinescreensaver/logs/onlinescreensaver.txt` dynamically using a 500KB cap check `$(stat -c%s "$LOGFILE")` before writing, saving the Kindle's rootfs from gigabytes of chatty debugging logs.

## 🔐 Security Standards
- **Secrets**: Never hardcode Telegram or API keys in `config.sh`.
- **secrets.sh**: All sensitive values live here and are ignored by Git. 
- **Binding**: The screensaver is *bind-mounted* to avoid modifying the root partition unnecessarily.

## 🛠️ Maintenance & Developer Gotchas

### ⚠️ Windows Line Endings (CRLF)
- **The Issue**: Editing scripts on Windows adds `\r` characters that break the Kindle's shell.
- **The Fix**: Always run `sed -i 's/\r$//' bin/*.sh` after scp-ing files. This is included in our main install command.

### 🔐 Telegram Secrets Structure
- **File**: `onlinescreensaver/bin/secrets.sh`
- **Content**:
  ```bash
  TELEGRAM_TOKEN="12345:ABCDE..."
  TELEGRAM_CHAT_ID="-12345678"
  ```
- **Note**: Ensure this file exists before running `install.sh` to avoid "missing secrets" warnings.

## 📈 Monitoring & Logs
- **Logs**: `/mnt/us/extensions/onlinescreensaver/logs/onlinescreensaver.txt` is the source of truth.
- **Diagnostics**: `dev` mode prints real-time status to the bottom of the Kindle screen.
- **Manual Kick**: `lipc-set-prop com.lab126.wifid cmState connect` can force a stuck radio.
