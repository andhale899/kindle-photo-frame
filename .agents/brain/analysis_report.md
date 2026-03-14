# 📔 Analysis Report: poja1993 vs. v2.5 Stable

I have performed a deep study of the `poja1993/onlinescreensaver` project. Below is the technical comparison.

## 📊 Feature Comparison

| Feature | poja1993 Implementation | v2.5-stable (Current) |
| :--- | :--- | :--- |
| **WiFi Activation** | Basic `wirelessEnable 1` | `wirelessEnable 1` + Airplane Mode Override |
| **Connection Loop** | Simple `ping` + 30s timeout | **Turbo 180s** + `wpa_cli reassociate` every 10s |
| **Zombie Radio Fix** | **None** (Assume wake) | **Adrenaline** (lipc kicks) + **Sledgehammer** (power button) |
| **RTC Wakeup** | Simple RTC set | **Early Bird** (60s lead-time warmup) |
| **Security** | Hardcoded logic | Externalized `secrets.sh` (Git Ignored) |
| **State Detection** | `ping` only | **Deep Diagnostics** (IP/State/SSID logging) |

## 🔍 Key Findings

### 1. The "Custom rtcwake" Experiment
`poja1993` included a custom `rtcwake` binary and attempted to use `-m mem` (Suspend-to-RAM). This is an attempt to force the hardware to stay "live" enough to wake up instantly. 
- **Verdict**: They commented this code out in the final version, likely because it causes **system crashes** or battery drain on newer Kindle firmware.

### 2. Why v2.5 is Superior
The `poja1993` project was designed for **Kindle Touch and PW2** (older firmware). On those devices, the WiFi radio was much "friendlier" in background mode.
On your modern Paperwhite, the system manager (`powerd`) puts the radio into a deep sleep that `poja1993` cannot break. **Our Sledgehammer approach** (`powerd_test -p`) is the only way to force the framework's "Eyes" open in background mode without manual interaction.

## ✅ Recommendation
Stay on **v2.5-stable**. It incorporates all the stability and logic of the original repos but adds the specific hardware "kicks" required for modern Kindle firmware.
