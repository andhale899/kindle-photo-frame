# OnlineScreensaver Extension (v4.2)

A robust, standalone screensaver override for jailbroken Kindles. This extension enables the device to fetch and display high-quality images from a remote source while bypassing the limitations of the default Kindle lockscreen.

## Key Features

- **Independent Operation**: Functions as a standalone KUAL extension without requiring the legacy ScreenSavers hack (linkss).
- **Proactive Connectivity**: Wakes the wireless radio in advance to ensure successful network synchronization.
- **Connection Recovery**: Actively manages the Kindle's connection framework to resolve "zombie" radio states.
- **Real-Time Status alerts**: Integrates with the Telegram Bot API to send system health and battery reports directly to your mobile device.
- **Diagnostic Mode**: Offers a specialized verbose mode for on-screen debugging and detailed log output.

## Installation

1. Deploy the `onlinescreensaver` directory to `/mnt/us/extensions/` on your Kindle.
2. **Configure Permissions**: Ensure all scripts are executable. From an SSH terminal:
   ```bash
   chmod +x /mnt/us/extensions/onlinescreensaver/bin/*.sh
   ```
3. **Activation**:
   - Open **KUAL** -> **OnlineScreensaver**.
   - Navigate to **Maintenance** -> **Install Standalone**.
   - The device will perform a soft reboot to establish the necessary system mounts.

## Configuration

### Secrets Configuration (`bin/secrets.sh`)
Store your private credentials here. This file is excluded from version control for your security:
```bash
TELEGRAM_TOKEN="your_bot_token"
TELEGRAM_CHAT_ID="your_chat_id"
```

### System Configuration (`bin/config.sh`)
Customize the core behavior of the extension:
- `IMAGE_URI`: The direct URL to your processed photo source.
- `RUN_MODE`: Set to `dev` for debugging or `prod` for stable background operation.
- `DEFAULTINTERVAL`: Frequency of updates in minutes.

## Operations

- **Manual Synchronize**: Triggers an immediate network check and screen update.
- **Diagnostic Check**: Validates the health of the scheduler, mount points, and log accessibility.

## Technical Notes
This extension uses a bind-mount strategy on `/usr/share/blanket/screensaver` to safely override system behavior without modifying core system partitions. It is designed to be lightweight and resilient against system-level power management events.
