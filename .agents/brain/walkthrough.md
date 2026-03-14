# Kindle Screensaver: The Phoenix Evolution (v4.0)

We have transformed your Kindle from a simple polled screensaver into an intelligent, self-healing photo frame.

## 🚀 Version Milestones

### 1. ⚡ v2.0: Turbo Radio
- **Turbo Ignition**: Wakes up 60s early for WiFi warmup.
- **Aggressive Reassociate**: Forces connection rather than waiting for background scans.

### 2. 🛡️ v2.6 - v2.8: The Sleepwalker
- **3-Strike Rule**: Stops battery drain if WiFi is consistently failing.
- **Sleepwalker Logic**: Forces the device back to sleep after an emergency wake.

### 3. 🎠 v3.0: The Carousel
- **The Vault**: Local cache of **all 15 images** from GitHub.
- **Lock Shuffle**: Populates 15 screensaver slots at once. Every time you lock/unlock manually, you see a new photo!
- **Offline Resilience**: Even if WiFi is dead for a week, you'll still see 15 different photos rotating every 15 minutes.

### 4. 📦 v4.0: The Phoenix
- **Self-Update Button**: Added **"Update Code from GitHub"** to the KUAL menu. No more `scp` needed to update your scripts!
- **Deep Audit Fixes**: 
  - Optimized `scheduler.sh` for long-term timing.
  - Replaced `seq` with `while` loops for compatibility with all Kindle versions.
  - Deployed `WIFI_NO_NET_PROBE` for rock-solid connection health.

## 🛠️ Performance & Stability
- **Battery**: Efficient cycles with passive rotation.
- **Logs**: Auto-rotating to prevent storage bloat.
- **Maintenance**: Check system health anytime via "Check Status" in the menu.

## 🏁 Final Step (The Last SCP)
Since the Kindle rebooted to apply the new menu, this is the last time you need to use a computer. From now on, just use the **"Update Code from GitHub"** button in your Kindle's **Maintenance** menu to sync with my future changes!
