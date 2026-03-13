# Standalone OnlineScreensaver with Telegram Alerts

This is a robust, standalone screensaver for jailbroken Kindles. It replaces the default lockscreen using a lightweight bind-mount strategy, avoiding the complexity and instability of the older `linkss` hack.

## Key Features
- **Standalone**: No dependency on the ScreenSavers hack.
- **Turbo Recovery (v2.5)**: 
  - **Early Bird**: Lead-time wake for hardware warm-up.
  - **Adrenaline**: Framework-level `lipc` kicks for the connection manager.
  - **Sledgehammer**: Simulates physical power button press if radio is "Zombie."
- **Telegram Alerts**: Receive live status updates and error reports on your phone.
- **Epic On-Screen Logs**: Diagnostic info printed directly on the Kindle screen.
- **Environment Modes**: Switch between `dev` (verbose) and `prod` (minimal).

## Installation
1. Copy the `onlinescreensaver` folder to `/mnt/us/extensions/`.
2. **IMPORTANT (Windows Users)**: Connect via SSH and fix line endings:
   ```bash
   sed -i 's/\r$//' /mnt/us/extensions/onlinescreensaver/bin/*.sh && chmod +x /mnt/us/extensions/onlinescreensaver/bin/*.sh
   ```
3. Open KUAL -> Online-Screensaver -> Maintenance -> **[WARNING] Install Standalone**.
4. The Kindle will reboot automatically.

## Configuration
1. **Secrets**: Create or edit `bin/secrets.sh`. This file is hidden from Git to protect your privacy:
   ```bash
   TELEGRAM_TOKEN="your_token_here"
   TELEGRAM_CHAT_ID="your_id_here"
   ```
2. **Main Settings**: Edit `bin/config.sh` to set your:
   - `IMAGE_URI`: Your photo source URL.
   - `RUN_MODE`: `dev` (verbose) or `prod` (stable).

## Usage
- **Update Now**: Triggers an immediate download and screen refresh.
- **Set Interval**: Choose your update frequency (e.g., 5 min, 1 hour).
- **Toggle Mode**: Switch between Dev and Prod settings for Telegram.
- **Check Status**: Verifies if the mount, scheduler, and logs are working properly.

## Acknowledgements
Based on the original `onlinescreensaver` v0.3 by peterson, refactored for modern standalone operation.
