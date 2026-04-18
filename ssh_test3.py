import paramiko
import sys

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('192.168.29.76', username='root', password='mario', timeout=10)

print('Applying rapid hotfix without waiting for GitHub Actions...')
cmd = """
cd /mnt/us/extensions/onlinescreensaver/bin
curl -H 'Cache-Control: no-cache' -sL https://raw.githubusercontent.com/andhale899/kindle-photo-frame/kindle-local-only-main/onlinescreensaver/bin/process_local.sh -o process_local_new.sh
sed -i 's/\r$//' process_local_new.sh
mv process_local_new.sh process_local.sh
chmod +x *.sh

echo "Running update..."
sh update.sh
"""

stdin, stdout, stderr = client.exec_command(cmd)
print(stdout.read().decode('utf-8'))
for ln in stderr.read().decode('utf-8').split('\n'):
    if ln: print('ERR:', ln)
client.close()
