# Kindle Photo Frame Pro (v4.2-Stable)

Transform your jailbroken Kindle into a high-performance digital photo frame. This system provides a seamless, automated pipeline for displaying your favorite photos alongside real-time weather and status information.

---

## 🌟 Features

### 1. Robust Image Pipeline
- **Google Photos Integration**: Automatically extracts images from a shared album.
- **E-Ink Optimization**: Images are processed into high-contrast grayscale (1072x1448) optimized specifically for the Kindle display.
- **Localized Overlays**: Personalized date, time, and weather information displayed on every photo.

### 2. Intelligent Weather System
- **Dual-Source Accuracy**: Primary weather data is fetched from **Open-Meteo** using precise geocoding for your city.
- **Fail-Safe Fallback**: Automatically switches to **wttr.in** if the primary source is unavailable, ensuring the temperature is never missing.

### 3. Advanced Power & Connectivity
- **Optimized Sleep Cycles**: Uses hardware-level scheduling to wake the device only when needed, maximizing battery life.
- **WiFi Management**: Actively manages the Kindle's wireless radio to ensure successful updates even in low-signal environments.
- **Local Caching**: Stores a "Vault" of 15 images locally, allowing the screensaver to rotate through photos even when offline.

### 4. Remote Monitoring
- **Telegram Alerts**: Receive instant notifications on your phone regarding update status, battery levels, and system health.

---

## 📋 Prerequisites

Before installation, ensure you have the following:
1. **Jailbroken Kindle**: Must have KUAL (Kindle Unified Application Launcher) installed.
2. **WiFi Connection**: A stable wireless network for your Kindle to reach GitHub and Weather APIs.
3. **GitHub Account**: To host the image processing workflow.
4. **Google Photos**: A shared album containing the photos you wish to display.
5. **SSH Access**: Ability to connect to your Kindle via PC (using PuTTY or OpenSSH).

---

## 🚀 Installation Guide

### Step 1: Repository Setup
1. **Fork this repository** to your own GitHub account.
2. Go to the **Settings** tab of your forked repo -> **Actions** -> **General** -> Set "Workflow permissions" to **Read and write permissions**.
3. Go to the **Actions** tab and click **"I understand my workflows, go ahead and enable them"**.

### Step 2: Configuration
1. Open `config/config.yml` in your forked repository.
2. Update the `album.url` with your Google Photos shared album link.
3. Update the `weather.location` with your "City, Country" (e.g., "Ahmednagar, IN").
4. Commit and push these changes.

### Step 3: Deploy to Kindle
1. Connect your Kindle to your PC.
2. Copy the `onlinescreensaver` folder to the `/extensions/` directory on your Kindle's user storage.
3. **Set Permissions**: Open a terminal/SSH session to your Kindle and run:
   ```bash
   chmod +x /mnt/us/extensions/onlinescreensaver/bin/*.sh
   ```
4. **Configure Secrets**: Edit `/mnt/us/extensions/onlinescreensaver/bin/secrets.sh` on the Kindle to add your Telegram Token and Chat ID.

### Step 4: Activation
1. Launch **KUAL** on your Kindle.
2. Select **OnlineScreensaver**.
3. Select **Maintenance** -> **Install Standalone**.
4. The device will reboot and begin the first update cycle.

---

## 🛠️ Usage & Operations

Your Kindle provides a specialized menu within KUAL for common tasks:
- **Update Now**: Triggers an immediate refresh of the current photo.
- **Check Status**: Displays a diagnostic report of the connection, schedule, and logs.
- **Maintenance**: Access tools for testing the Telegram bot or uninstalling the extension.

---

## 🗑️ Uninstallation

To completely remove the Kindle Photo Frame system:
1. Open **KUAL** -> **OnlineScreensaver** -> **Maintenance**.
2. Select **Uninstall Standalone**. This will restore the default Kindle screensaver behavior.
3. Once the Kindle reboots, you may safely delete the `/mnt/us/extensions/onlinescreensaver` folder from your Kindle.

---

## 📈 Monitoring & Logs

- **On-Screen**: In development mode, status messages appear at the bottom of the screensaver.
- **Telegram**: Error reports and status updates are sent directly to your configured Telegram bot.
- **Local Logs**: Detailed execution logs are stored at `/mnt/us/extensions/onlinescreensaver/logs/kindle.log`.

---
*Developed for stability and reliability. Based on the original OnlineScreensaver concept.*
