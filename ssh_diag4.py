import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('192.168.29.76', username='root', password='mario', timeout=10)

BINDIR = '/mnt/us/extensions/onlinescreensaver/bin'
VAULT  = '/mnt/us/extensions/onlinescreensaver/vault'

# Check if overlay was actually embedded (files should be different sizes now vs 14 bytes)
print('=== Vault sizes AFTER musl fix ===')
stdin, stdout, stderr = client.exec_command(f'ls -lh {VAULT}/')
print(stdout.read().decode('utf-8', errors='replace'))

# Check if convert ran (look for overlay log messages)
print('=== Recent process_local logs ===')
stdin, stdout, stderr = client.exec_command(
    'grep PROCESS /mnt/us/extensions/onlinescreensaver/logs/onlinescreensaver.txt | tail -30'
)
print(stdout.read().decode('utf-8', errors='replace'))

# Check where -lt -gt error comes from (it's in scheduler.sh battery check)
print('=== Find -lt/-gt culprit ===')
stdin, stdout, stderr = client.exec_command(
    "grep -n 'BATT\\|-lt\\|-gt\\|gasgauge' "
    f"{BINDIR}/update.sh {BINDIR}/scheduler.sh 2>&1 | head -20"
)
print(stdout.read().decode('utf-8', errors='replace'))

client.close()
