import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('192.168.29.76', username='root', password='mario', timeout=10)

print('Fixing CRLF line endings on the Kindle and running update...')
cmd = """
# Fix all shell scripts (remove \r)
cd /mnt/us/extensions/onlinescreensaver/bin/
sed -i 's/\r$//' *.sh
sed -i 's/\r$//' secrets.sh.template
sed -i 's/\r$//' secrets.sh

# Run the update again
echo "Running update.sh..."
sh update.sh
"""

stdin, stdout, stderr = client.exec_command(cmd)
print(stdout.read().decode('utf-8'))
for ln in stderr.read().decode('utf-8').split('\n'):
    if ln: print('ERR:', ln)
client.close()
