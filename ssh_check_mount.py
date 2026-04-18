import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('192.168.29.76', username='root', password='mario', timeout=10)

def run(cmd):
    stdin, stdout, stderr = client.exec_command(cmd)
    out = stdout.read().decode('utf-8', errors='replace').strip()
    err = stderr.read().decode('utf-8', errors='replace').strip()
    return out, err

print('=== Full log (last 50 lines) ===')
out, _ = run('tail -n 50 /mnt/us/extensions/onlinescreensaver/logs/onlinescreensaver.txt')
print(out)

print('\n=== Screensaver folder state ===')
out, _ = run('ls -la /mnt/us/onlinescreensaver/screensaver/ 2>&1')
print(out)

print('\n=== Active screensaver symlinks/mounts ===')
out, _ = run('mount | grep screensaver 2>&1; echo "---"; ls -la /var/local/system/screensavers/ 2>&1 | head -10')
print(out)

print('\n=== Upstart / screensaver service status ===')
out, _ = run('initctl status onlinescreensaver 2>&1; initctl status lab126-screensaver-start 2>&1')
print(out)

print('\n=== LINKSS / screensaver hack status ===')
out, _ = run('ls -la /var/local/system/screensavers/ 2>&1; cat /var/local/system/screensavers/.linkss 2>&1 | head -5')
print(out)

print('\n=== onlinescreensaver.conf ===')
out, _ = run('cat /mnt/us/extensions/onlinescreensaver/bin/onlinescreensaver-mount.conf 2>&1')
print(out)

client.close()
