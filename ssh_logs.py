import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('192.168.29.76', username='root', password='mario', timeout=10)

def run(cmd):
    stdin, stdout, stderr = client.exec_command(cmd)
    out = stdout.read().decode('utf-8', errors='replace').strip()
    return out

print('=== utils.sh wait_for section ===')
print(run('grep -n "wirelessEnable" /mnt/us/extensions/onlinescreensaver/bin/utils.sh'))
print(run('grep -n "wlan__off\|rtcwake\|wait_for" /mnt/us/extensions/onlinescreensaver/bin/utils.sh'))

print('\n=== Extension files present? ===')
print(run('ls /mnt/us/extensions/onlinescreensaver/bin/ 2>&1'))

print('\n=== Screensaver mounts ===')
out = run('grep screensaver /proc/mounts 2>&1')
print(out if out else 'NO SCREENSAVER MOUNTS')

print('\n=== Scheduler still running? ===')
print(run('ps | grep scheduler | grep -v grep'))

print('\n=== WiFi state ===')
print(run('lipc-get-prop com.lab126.cmd wirelessEnable 2>&1'))

print('\n=== Screensaver folder files ===')
print(run('ls -lh /mnt/us/onlinescreensaver/screensaver/ | head -8'))

client.close()
