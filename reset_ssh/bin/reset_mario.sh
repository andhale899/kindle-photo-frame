#!/bin/sh

# Mount root filesystem as read-write
mntroot rw

# Reset root password to 'mario'
echo "root:mario" | chpasswd

# Print message on Kindle screen
eips -c
eips -c
eips 10 20 "SSH password has been reset!"
eips 10 22 "New password is: mario"
eips 10 24 "You can now connect via WiFi or USBNet."


# Remount as read-only
mntroot ro
