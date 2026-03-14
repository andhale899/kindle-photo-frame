# 🔍 Kindle Photo Frame — Deep Bug & Issue Analysis

**Analyzed:** README.md, AI_CONTEXT.md, `onlinescreensaver/bin/*.sh`, [config.yml](file:///c:/Users/PankajAndhale/Desktop/Hobby/kindle-photo-frame/config/config.yml), [kindle_logs.txt](file:///c:/Users/PankajAndhale/Desktop/Hobby/kindle-photo-frame/kindle_logs.txt) (2033 lines, Mar 13–14 2026)

---

## 🐛 CONFIRMED BUGS (From Code + Logs)

### Bug 1 — 🚨 TELEGRAM ERROR STORM on Boot (Log lines 48–222, 148–221, etc.)

**What happens:** Every time the scheduler starts, it sends ~40–70 Telegram messages in under 2 seconds, flooding the log with:
```
TELEGRAM ERROR (6): 
```
Curl error code `6` = **"Could not resolve host"** — the scheduler fires Telegram calls the instant it launches, *before WiFi has connected after reboot*.

**Root cause in [utils.sh](file:///c:/Users/PankajAndhale/Desktop/Hobby/kindle-photo-frame/onlinescreensaver/bin/utils.sh):** The [log()](file:///c:/Users/PankajAndhale/Desktop/Hobby/kindle-photo-frame/onlinescreensaver/bin/utils.sh#49-80) function calls [send_telegram_msg()](file:///c:/Users/PankajAndhale/Desktop/Hobby/kindle-photo-frame/onlinescreensaver/bin/utils.sh#2-36) for every message. The scheduler immediately logs `"Full two day schedule: ..."` and `"--- Background Loop Start ---"` right after boot, before WiFi is up.

**The [send_telegram_msg()](file:///c:/Users/PankajAndhale/Desktop/Hobby/kindle-photo-frame/onlinescreensaver/bin/utils.sh#2-36) retry loop in [utils.sh](file:///c:/Users/PankajAndhale/Desktop/Hobby/kindle-photo-frame/onlinescreensaver/bin/utils.sh) (line 6–15)** tries google.com/8.8.8.8 for ~30 seconds before giving up — but the outer [log()](file:///c:/Users/PankajAndhale/Desktop/Hobby/kindle-photo-frame/onlinescreensaver/bin/utils.sh#49-80) loop is calling it **for every chatty logger call**, causing a retry storm.

**Fix needed:** Block Telegram sends until after the first successful `CONNECTED=1` in [update.sh](file:///c:/Users/PankajAndhale/Desktop/Hobby/kindle-photo-frame/onlinescreensaver/bin/update.sh), or gate Telegram at startup with a single WiFi-ready check before allowing any notifications.

---

### Bug 2 — ⚠️ `WIFI_STATE` String-vs-Integer Comparison (update.sh line 50)

```sh
if [ "$WIFI_STATE" -eq 0 ]; then
```

`lipc-get-prop com.lab126.cmd wirelessEnable` can return non-numeric output on some firmware versions (empty string, or error text like `"LIPC Error"`). If this happens, `-eq` on a non-integer causes the script to **crash or behave incorrectly** here.

**Fix:** Add a guard: `if [ -n "$WIFI_STATE" ] && [ "$WIFI_STATE" -eq 0 ] 2>/dev/null; then`

---

### Bug 3 — 🐛 SLEDGEHAMMER Fires Every 10s After 120s Mark (update.sh lines 111–122)

**The logic:**
```sh
if [ $(( $NETWORK_TIMEOUT - $TIMER )) -ge 60 ] && [ -z "$IP" ] && [ "$SSIDS" = "" ]; then
```
This check runs **inside the `$TIMER % 10 -eq 0` block** — so after 120s mark is hit, the Sledgehammer (`powerd_test -p`) fires **every 10 seconds** until timeout.

**From the logs (lines 1920–1956):** The log shows the Sledgehammer firing **9+ consecutive times** over the last 80 seconds:
```
07:50:21 SLEDGEHAMMER: Radio is ZOMBIE. Fire...
07:50:39 SLEDGEHAMMER: Radio is ZOMBIE. Fire...  ← every 10s
07:50:57 SLEDGEHAMMER: Radio is ZOMBIE. Fire...
...continuing to 07:53:53
```

This is **not the intended "polite" behavior** described in AI_CONTEXT. It should fire **once**, with perhaps one retry. Repeated simulated power button presses can interfere with the device state and show the lock screen repeatedly.

**Fix:** Add a `SLEDGEHAMMER_FIRED=0` flag. Only fire if `SLEDGEHAMMER_FIRED -eq 0`, then set it to `1`.

---

### Bug 4 — 🐛 `SSIDS` Variable Used Before Set (update.sh line 111)

The Sledgehammer condition checks `[ "$SSIDS" = "" ]` — but `SSIDS` is only ever written inside the `$TIMER % 10` block itself (line 128), **after the Sledgehammer check at line 111**. So on the **first** 10-second tick, `SSIDS` is uninitialized (empty), making the Sledgehammer trigger prematurely on the first opportunity.

**Fix:** Initialize `SSIDS=""` before the while loop (line 76) so empty vs unset is explicit.

---

### Bug 5 — 📁 Log File Growing Unbounded — No Rotation

The log at `/mnt/us/extensions/onlinescreensaver/logs/onlinescreensaver.txt` is append-only with no size limit or rotation. The attached [kindle_logs.txt](file:///c:/Users/PankajAndhale/Desktop/Hobby/kindle-photo-frame/kindle_logs.txt) is **186 KB** just from a single day of testing. With chatty [logger()](file:///c:/Users/PankajAndhale/Desktop/Hobby/kindle-photo-frame/onlinescreensaver/bin/utils.sh#82-87) calls every 10 seconds during WiFi failures, the log could fill `/mnt/us` storage over weeks.

**Fix:** Add log rotation in [utils.sh](file:///c:/Users/PankajAndhale/Desktop/Hobby/kindle-photo-frame/onlinescreensaver/bin/utils.sh) — cap at e.g. 500KB and rotate:
```sh
if [ $(stat -c%s "$LOGFILE" 2>/dev/null || echo 0) -gt 512000 ]; then
    mv "$LOGFILE" "${LOGFILE}.old"
fi
```

---

### Bug 6 — 🔌 `DISABLE_WIFI` Flag Silently Fails if WiFi Was Never Actually Disabled (update.sh line 223)

```sh
DISABLE_WIFI=0
...
if [ "$WIFI_STATE" -eq 0 ]; then
    DISABLE_WIFI=1
```
But `DISABLE_WIFI=0` is **also the default in [config.sh](file:///c:/Users/PankajAndhale/Desktop/Hobby/kindle-photo-frame/onlinescreensaver/bin/config.sh) line 29**, so if config loads after the variable is set in update.sh, the config will **reset it to 0**, causing WiFi to never be re-disabled even if it was originally off.

**Fix:** Rename the runtime flag to something like `SHOULD_DISABLE_WIFI` to avoid collision with the config variable.

---

### Bug 7 — 📅 Date Format Corruption in Logs — "GMT+5:30100"

Every single log line shows:
```
Fri Mar 13 19:27:31 GMT+5:30100 2026
```
The `100` is the year component getting concatenated with the timezone. This is a `$(date)` format issue on Kindle's busybox. The year `2026` is being appended directly after the timezone offset without spacing.

This doesn't break execution but it makes log parsing by any external tool or human **very confusing**. The year appears to be `100` and `2026` appears to be a random number.

**Fix in [utils.sh](file:///c:/Users/PankajAndhale/Desktop/Hobby/kindle-photo-frame/onlinescreensaver/bin/utils.sh) line 65:** Use an explicit date format:
```sh
echo "$(date '+%Y-%m-%d %H:%M:%S %Z') [v$VERSION]: $MSG" >> "$LOGFILE"
```

---

### Bug 8 — 🔄 [set_interval.sh](file:///c:/Users/PankajAndhale/Desktop/Hobby/kindle-photo-frame/onlinescreensaver/bin/set_interval.sh) Service Restart Fails Silently (Log line 31)

From logs:
```
19:41:57  Error: Failed to start service.
```
Then shortly after it works. The [set_interval.sh](file:///c:/Users/PankajAndhale/Desktop/Hobby/kindle-photo-frame/onlinescreensaver/bin/set_interval.sh) script tries to restart the upstart job, but it sometimes fails (likely a race condition — the old job is still shutting down). There's no retry logic.

---

### Bug 9 — 🖼️ `eips` Call Shows Old Version Number on Screen (update.sh line 168)

```sh
eips 0 0 "Updating Screen v$VERSION... (Batt: $BATT)"
```
`$BATT` is fetched at line 39 **before WiFi tries to connect**, so if connection takes 90 seconds, the battery percentage displayed is stale. Minor cosmetic issue.

---

### Bug 10 — 🔬 Sledgehammer Polite Check is Fragile (update.sh lines 113–114)

```sh
PSTATE=$(lipc-get-prop com.lab126.powerd status | grep "Powerd state" | awk '{print $3}')
if [ "$PSTATE" = "Screen" ] || [ "$PSTATE" = "Ready" ]; then
```
It only checks if the 3rd word is `"Screen"` (for "Screen Saver") or `"Ready"`. This is very fragile — any firmware change to the output format of `powerd status` will break this check and potentially the Sledgehammer will never fire OR always fire. The full state string `"Screen Saver"` is split across two words, so `awk '{print $3}'` only gets `"Screen"`, not `"Screen Saver"`.

---

## ⚠️ POTENTIAL ISSUES (Architecture & Design Concerns)

### Issue 1 — ⚡ Battery Drain in Version 2.5 from Repeated Sledgehammer + 180s WiFi Polling

From the recent logs, battery went from **82% → 78%** in ~45 minutes (lines 1820–2022) during morning hours where WiFi was consistently failing. The script polls every 10 seconds and fires the Sledgehammer every 10s, keeping the CPU and radio driver active the entire 180-second window for every failed cycle. **The 3-Strike passive mode was NOT triggered** in the v2.5 logs despite 3+ consecutive failures — worth verifying the strike file path persists across reboots.

### Issue 2 — ⏰ Early Bird Math May Overshoot with Short Intervals

```sh
WAIT_TIME=$(( 60 * $(get_time_to_next_update) ))
if [ $WAIT_TIME -gt 120 ]; then
    EARLY_WAIT=$(( $WAIT_TIME - 60 ))
```
With a 5-minute interval, `WAIT_TIME = 300s`. `EARLY_WAIT = 240s`. The Kindle wakes 60s early. **But the 60s is spent in [update.sh](file:///c:/Users/PankajAndhale/Desktop/Hobby/kindle-photo-frame/onlinescreensaver/bin/update.sh)'s WiFi loop**, so if it connects in 5s, the remaining 55s is dead time before the next cycle. Not a bug, but at very short intervals (≤2 min), Early Bird provides no benefit and adds complexity.

### Issue 3 — 🔁 `wakeupFromSuspend` Breaks the Schedule

The logs show the device frequently waking **much earlier than expected** (`wakeupFromSuspend 91` when RTC was set to 263). This is because any external resumption (user picking up the device, charger plug, etc.) breaks out of [wait_for()](file:///c:/Users/PankajAndhale/Desktop/Hobby/kindle-photo-frame/onlinescreensaver/bin/utils.sh#157-188). The scheduler then immediately fires another update cycle. With a 5-min interval, this means **updates fire much more often than configured** when the device is in active use.

### Issue 4 — 🛜 `TEST_DOMAIN` is `www.google.com` but Diagnostic pings `google.com`

In [utils.sh](file:///c:/Users/PankajAndhale/Desktop/Hobby/kindle-photo-frame/onlinescreensaver/bin/utils.sh) line 9, [send_telegram_msg()](file:///c:/Users/PankajAndhale/Desktop/Hobby/kindle-photo-frame/onlinescreensaver/bin/utils.sh#2-36) pings `google.com` (without www). In [update.sh](file:///c:/Users/PankajAndhale/Desktop/Hobby/kindle-photo-frame/onlinescreensaver/bin/update.sh) line 78, it pings `$TEST_DOMAIN` which is configured as `www.google.com`. These are inconsistent. If Google DNS blocks ICMP, pings to `www.google.com` may fail even when DNS works, triggering false connection failures. A better test is `ping 8.8.8.8`.

### Issue 5 — 🔒 `source` vs `.` Shell Compatibility

Scripts use `source ./config.sh` but the shebang is `#!/bin/sh`. On Kindle's busybox `ash`, `source` is *usually* available, but it's a bashism. The POSIX-correct equivalent is `. ./config.sh`. If the shell ever defaults to a stricter POSIX shell, the entire script silently fails to load config.

---

## 🔨 THE SLEDGEHAMMER — Deep Dive & Alternatives

### What it is and what it does
The Sledgehammer calls `powerd_test -p` which **simulates a physical power button press**. On most Kindles, a power button press *while in screensaver* causes the device to briefly wake its display and hardware paths, including the full-power WiFi radio path. This is the only way discovered to pull the WiFi radio out of a "zombie" state where `wlan0` shows UP but `SSIDS=[none]`.

### Why it sometimes works
The Kindle's WiFi hardware has two power paths:
1. **Low-power standby** — radio reports UP but doesn't scan (zombie)
2. **Full-power wake** — triggered by hardware events like button press

`powerd_test -p` forces path #2.

### Why it's a Sledgehammer
- It physically toggles the screen (brief flash)
- Done 9+ times per failure window (as seen in logs)
- Could theoretically confuse the powerd state machine
- Not a documented API — could break on firmware update

### Alternatives

| Alternative | How | Pros | Cons |
|---|---|---|---|
| **`lipc-set-prop com.lab126.wifid ensureConnection wifi`** | Forces Connection Manager to try reconnect | Documented-ish lipc call, no screen flash | May not break zombie state |
| **`ifconfig wlan0 down && ifconfig wlan0 up`** | Resets wlan0 at kernel level | Very low-level, works on standard Linux | May race with wifid daemon, could lock up |
| **`wpa_cli -i wlan0 disconnect && reassociate`** | Reconnects at WPA supplicant level | Standard wpa_supplicant API | Only works if radio is actually scanning |
| **`lipc-set-prop com.lab126.cmd wirelessEnable 0` + `1` with 5s sleep** | Full radio power cycle via framework | Already in code as TURBO RESET | Slower (8s total); already implemented |
| **`lipc-set-prop com.lab126.wifid cmState connect`** | Directly commands CM to connect state | Mentioned in AI_CONTEXT as "Manual Kick" | Empirically unreliable in some states |
| **KOReader `NetworkMgr`** | Use KOReader's network manager instead | Community-tested, actively maintained | Requires KOReader installation |
| **Increase RTC wake-up window (wake 120s early instead of 60s)** | Give radio more warmup time | No Sledgehammer needed | Uses slightly more battery |

> **Recommended approach:** The TURBO RESET (already in code) is effectively the "polite" version of the Sledgehammer. The Sledgehammer should only fire **once per update cycle**, not every 10 seconds. Fix Bug #3 first — that single change will make the Sledgehammer behave as originally intended.

---

## 🌐 HOW THE COMMUNITY DOES ONLINE SCREENSAVERS

### 1. Classic `onlinescreensaver` (Peterson's original)
- Fetches a URL on a schedule using [rtcwake](file:///c:/Users/PankajAndhale/Desktop/Hobby/kindle-photo-frame/onlinescreensaver/bin/rtcwake) + `lipc` events
- Uses `linkss` screensaver hack to replace system screensavers
- Your project is a heavily extended fork of this
- Still actively discussed on [MobileRead forums](https://www.mobileread.com)

### 2. KOReader + `wakeupmgr` (Recommended Modern Approach)
- KOReader has a built-in **screensaver from folder** feature
- `wakeupmgr` can schedule a script to run at intervals (like a cron)
- The script downloads a new image to the folder
- KOReader picks it up automatically on next screensaver activation
- **No Sledgehammer needed** — KOReader handles WiFi via its own `NetworkMgr`
- Actively maintained, model-agnostic, open source
- Caveats: requires KOReader; WiFi + download at wake still drains battery

### 3. Home Assistant / Local Server Approach
- Serve the image from a **local server** (Pi, NAS) instead of GitHub
- Kindle fetches from `192.168.x.x` — much faster, no DNS issues
- Image can be pre-generated by HA automations
- Eliminates GitHub Actions dependency and external DNS failures

### 4. Fully Offline Static Screensaver
- Use Calibre/EPUB trick: convert image → ebook cover → "Send to Kindle"
- Enable "show cover on lock screen"
- No jailbreak, no WiFi, no battery drain
- Downside: manual update only, no rotation

### 5. `WinterBreak` Jailbreak + New Methods (2025)
- New universal jailbreak (Jan 2025) works on all models since Paperwhite 2
- Modern approach: jailbreak → KOReader → wakeupmgr scheduled script
- Community recommends KOReader over bare-shell screensaver hacks for reliability

---

## 📋 Priority Fix Summary

| Priority | Bug | Effort |
|---|---|---|
| 🔴 Critical | Bug #3: Sledgehammer fires every 10s (not once) | 2 lines |
| 🔴 Critical | Bug #1: Telegram storm on boot before WiFi is ready | ~10 lines |
| 🟠 High | Bug #5: Log file unbounded growth | ~5 lines |
| 🟠 High | Bug #2: WIFI_STATE non-integer crash risk | 1 line |
| 🟡 Medium | Bug #7: Date format corruption in logs | 1 line |
| 🟡 Medium | Bug #4: SSIDS uninitialized before check | 1 line |
| 🟡 Medium | Bug #6: DISABLE_WIFI flag overwritten by config | rename |
| 🟢 Low | Bug #10: Sledgehammer polite check fragile awk parse | 1 line |
| 🟢 Low | Bug #9: Stale battery shown on screen | 1 line |
