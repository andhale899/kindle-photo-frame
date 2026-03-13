# 🖼️ Kindle Photo Frame (v2.5 Stable)

A complete end-to-end system to turn your jailbroken Kindle into a dynamic digital photo frame with weather, time, and live Telegram alerts.

---

## 🏗️ Architecture

### 1. 🐍 The Backend (GitHub Actions)
Scrapes a Google Photos shared album, processes images for the Kindle E-Ink screen (1072×1448 grayscale), overlays weather/time, and hosts the results on the `processed-photos` branch.
- **Location**: `.github/workflows/` and `scripts/`
- **Features**: No API keys, free weather (wttr.in), hourly auto-refresh.

### 2. 📡 The Frontend (Kindle Extension)
A standalone, robust screensaver extension for the Kindle that downloads the latest photo and handles the display.
- **Location**: `onlinescreensaver/`
- **Features**: 
  - **Turbo Early Bird**: Wakes up 60s early to warm up WiFi.
  - **Adrenaline Shot**: Forced framework-level WiFi kicks.
  - **The Sledgehammer**: Emergency power-button simulation for deep sleep recovery.
  - **Deep Diagnostics**: Live SSID/IP/State logging in `dev` mode.
  - **Telegram Alerts**: Push notifications for status and errors.

---

## 🚀 Quick Start (Deployment)

### 1. Backend Setup
1. Push this repo to your GitHub.
2. Go to **Actions** and click **"Enable workflows"**.
3. Edit `config/config.yml` with your Google Photos album URL.

Run this in PowerShell to install the **v2.5-stable** extension:
```powershell
# Replace <KINDLE_IP> with yours
scp -r .\onlinescreensaver root@<KINDLE_IP>:/mnt/us/extensions/; ssh root@<KINDLE_IP> "sed -i 's/\r$//' /mnt/us/extensions/onlinescreensaver/bin/*.sh && chmod +x /mnt/us/extensions/onlinescreensaver/bin/*.sh && /mnt/us/extensions/onlinescreensaver/bin/install.sh"
```

---

## 🔐 Security
Your Telegram credentials are kept secure in `onlinescreensaver/bin/secrets.sh` (ignored by Git). See the [Kindle Extension README](onlinescreensaver/README.md) for setup details.

---

## 🛠️ File Structure
```
├── .github/workflows/   ← Backend: Hourly refresh job
├── config/              ← Backend: Scraper/Weather settings
├── scripts/             ← Backend: Image processing logic
├── onlinescreensaver/   ← Frontend: The Kindle Extension (v2.5)
│   ├── bin/             ← Shell scripts & secrets
│   └── menu.json        ← KUAL Menu definition
└── run_local.py         ← Test the photo scraper locally
```

---

## 📈 Monitoring
- **Telegram**: Enable `dev` mode to get live "Heartbeat" pings on your phone.
- **Kindle Screen**: Errors and WiFi status are printed at the bottom of the screen in `dev` mode.

---
*Based onpeterson's onlinescreensaver, redesigned for stability and modern developer features.*
