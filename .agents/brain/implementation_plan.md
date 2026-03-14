## v3.0-stable: "The Carousel" (Multi-Image Rotation)
Major architectural upgrade focusing on offline resilience and dynamic local rotation.

## Goal Description
Utilize the full potential of your photo generation script. v3.0 downloads all 15 images to a local "Vault" and rotates them locally every 15 minutes. This ensures the Kindle always shows a fresh image even when WiFi is absent or when you wake the device.

## v3.0-stable Key Features
- **The Library Sync**: `update.sh` now loops to download `photo_01.png` through `photo_15.png` on every successful connection.
- **The Vault**: Local storage in `/mnt/us/extensions/onlinescreensaver/vault/` ensures 15 images are always ready.
- **Local Carousel**: Every update cycle, the script picks the *next* image in line (1 -> 2 -> ... -> 15) and prepares the screensaver slots.
- **Passive Reliability**: In 3-Strike Mode, the Kindle stops searching for WiFi but **continues to rotate images from the Vault**, saving battery while staying dynamic.
- **Stability**: Add `WIFI_NO_NET_PROBE` to fix "rejection" issues on local networks.
Final audit of the Kindle Screensaver project to 'repair' any lingering script inconsistencies and implement 'The Sleepwalker' re-suspend logic.

## Goal Description
The Sledgehammer (power button) wakes the device to the Active menu. v2.8-stable will fire the Sledgehammer again at the end of the cycle to force the device back to sleep if it was the reason for the wake.

## v2.8-stable Key Features
- **Automatic Re-suspend**: If Sledgehammer was fired to wake the radio, fire it again at the end of the script to put the device back to sleep.
- **State Guard**: Only re-suspend if the device is still in the "Active" state and no user interaction was detected.
- **Grace Period**: Wait 5 seconds after the last `eips` refresh before suspending.
- **Default Cadence**: Hardcode `DEFAULTINTERVAL=15` as the new project standard.

## v2.6-stable: The "Polite Shot" & Battery Optimizer
- **User Activity Protection**: Check `com.lab126.powerd status`. Only fire Sledgehammer if state is `Screen Saver`.
- **Three-Strike Rule**: Track consecutive WiFi failures in `/tmp/wifi_failure_count`.
- **Passive Mode**: After 3 failures, skip aggressive kicks (Sledgehammer/Turbo) and only do a passive ping to save battery.
- **Auto-Reset**: Reset the failure count as soon as WiFi success is confirmed.

## User Review Required
> [!IMPORTANT]
> This change moves your Telegram Token and Chat ID to a new file: `onlinescreensaver/bin/secrets.sh`.
> You will need to re-enter your credentials in this new file after the update.

## Proposed Changes

### [The Carousel Architecture]
Implements the multi-image local rotation system.

#### [NEW] [vault directory](file:///mnt/us/extensions/onlinescreensaver/vault/)
- Stores `photo_01.png` to `photo_15.png`.

#### [MODIFY] [config.sh](file:///c:/Users/andha/OneDrive/Desktop/kindle_photo_frame/onlinescreensaver/bin/config.sh)
- Add `VAULT_DIR="/mnt/us/extensions/onlinescreensaver/vault"`
- Add `VAULT_COUNT=15`

#### [MODIFY] [update.sh](file:///c:/Users/andha/OneDrive/Desktop/kindle_photo_frame/onlinescreensaver/bin/update.sh)
- Implement `sync_vault()`: Loop `1..$VAULT_COUNT` and download missing/updated images.
- Implement `rotate_vault()`: Use a state file in `/tmp` to track the last index, increment, and copy the corresponding vault image to the screensaver slots.
- **Offline Guard**: If WiFi fails or strikes occur, skip `sync_vault` but *always* run `rotate_vault`.

#### [MODIFY] [utils.sh](file:///c:/Users/andha/OneDrive/Desktop/kindle_photo_frame/onlinescreensaver/bin/utils.sh)
- Add `pad_index()` helper for `01`, `02` formatting.

#### [NEW] [WIFI_NO_NET_PROBE](file:///c:/Users/andha/OneDrive/Desktop/kindle_photo_frame/WIFI_NO_NET_PROBE)
- Empty file to be placed in `/mnt/us` to prevent WiFi "internet check" handshakes.

### [Security Hardening]
Move sensitive variables out of the main configuration to prevent accidental leaks.

#### [NEW] [secrets.sh](file:///c:/Users/andha/OneDrive/Desktop/kindle_photo_frame/onlinescreensaver/bin/secrets.sh)
- Placeholder for `TELEGRAM_TOKEN` and `TELEGRAM_CHAT_ID`.

#### [MODIFY] [.gitignore](file:///c:/Users/andha/OneDrive/Desktop/kindle_photo_frame/.gitignore)
- Add `onlinescreensaver/bin/secrets.sh` to prevent it from being committed.

#### [MODIFY] [config.sh](file:///c:/Users/andha/OneDrive/Desktop/kindle_photo_frame/onlinescreensaver/bin/config.sh)
- Remove hardcoded Telegram credentials.
- Add logic to source `secrets.sh` if present.

### [Script Repair & Final Polish]
Ensure consistency and reliability across the "Turbo Early Bird" implementation.

#### [MODIFY] [update.sh](file:///c:/Users/andha/OneDrive/Desktop/kindle_photo_frame/onlinescreensaver/bin/update.sh)
- Refine v2.0 logic.
- Ensure all logs are consistent.

#### [MODIFY] [utils.sh](file:///c:/Users/andha/OneDrive/Desktop/kindle_photo_frame/onlinescreensaver/bin/utils.sh)
- Ensure all functions handle the absence of secrets gracefully.

#### [MODIFY] [install.sh](file:///c:/Users/andha/OneDrive/Desktop/kindle_photo_frame/onlinescreensaver/bin/install.sh)
- Ensure the new secret file structure is supported.

## Verification Plan

### Automated Tests
- Run `status.sh` on the Kindle post-install to verify service health.
- Check `kindle_logs.txt` to confirm "The Early Bird" wakeup is functioning.

### Manual Verification
- Confirm Telegram alerts are received after updating `secrets.sh`.
- Verify on-screen "WiFi: searching" indicators are visible.
