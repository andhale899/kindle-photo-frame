import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('192.168.29.76', username='root', password='mario', timeout=10)

# 1. Check vault file sizes (should be big if convert worked)
print('=== Vault files ===')
stdin, stdout, stderr = client.exec_command('ls -lh /mnt/us/extensions/onlinescreensaver/vault/')
print(stdout.read().decode('utf-8'))

# 2. Test convert binary directly
print('=== Testing convert binary ===')
stdin, stdout, stderr = client.exec_command(
    'LD_LIBRARY_PATH=/mnt/us/extensions/onlinescreensaver/bin/libs '
    'MAGICK_HOME=/mnt/us/extensions/onlinescreensaver/bin '
    'MAGICK_CONFIGURE_PATH=/mnt/us/extensions/onlinescreensaver/bin/libs '
    '/mnt/us/extensions/onlinescreensaver/bin/convert --version 2>&1'
)
print(stdout.read().decode('utf-8'))
print(stderr.read().decode('utf-8'))

# 3. Check what's causing the -lt -gt error (check battery parsing)
print('=== Battery check ===')
stdin, stdout, stderr = client.exec_command(
    'gasgauge-info -s 2>/dev/null || cat /sys/class/power_supply/bd7181x_bat/capacity 2>/dev/null || echo "no battery info"'
)
print(stdout.read().decode('utf-8'))

# 4. Pull last 15 lines of log
print('=== Last log entries ===')
stdin, stdout, stderr = client.exec_command('tail -n 15 /mnt/us/extensions/onlinescreensaver/logs/onlinescreensaver.txt')
print(stdout.read().decode('utf-8'))

client.close()
