import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('192.168.29.76', username='root', password='mario', timeout=10)

BINDIR = '/mnt/us/extensions/onlinescreensaver/bin'

print('=== Hotfixing process_local.sh on Kindle ===')
cmd = f"""
curl -H 'Cache-Control: no-cache' -sL \
  https://raw.githubusercontent.com/andhale899/kindle-photo-frame/kindle-local-only-main/onlinescreensaver/bin/process_local.sh \
  -o {BINDIR}/process_local_new.sh

sed -i 's/\r$//' {BINDIR}/process_local_new.sh
mv {BINDIR}/process_local_new.sh {BINDIR}/process_local.sh
chmod +x {BINDIR}/process_local.sh

echo "--- Running update.sh ---"
cd {BINDIR}
sh update.sh
"""

stdin, stdout, stderr = client.exec_command(cmd)
out = stdout.read().decode('utf-8', errors='replace')
err = stderr.read().decode('utf-8', errors='replace')
print(out)
# Only show meaningful errors
for ln in err.split('\n'):
    if ln and 'Total' not in ln and '%' not in ln and '---' not in ln:
        print('ERR:', ln)

client.close()
