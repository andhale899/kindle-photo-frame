import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('192.168.29.76', username='root', password='mario', timeout=10)

print('Updating Kindle directly over SSH...')
cmd = """
cd /tmp
rm -f update.zip
curl -L -o update.zip https://github.com/andhale899/kindle-photo-frame/releases/latest/download/KindlePhotoFrame_5.0-local.zip

# Backup old secrets
cp /mnt/us/extensions/onlinescreensaver/bin/secrets.sh /tmp/secrets_bak.sh

# Unzip and overwrite
unzip -o update.zip -d /mnt/us/
chmod +x /mnt/us/extensions/onlinescreensaver/bin/*.sh

# Restore secrets but MAKE SURE we add ALBUM_URL if it's missing!
ALBUM_URL="https://photos.app.goo.gl/yBPwxSGuEEnwnhGk9"
if ! grep -q "ALBUM_URL" /tmp/secrets_bak.sh; then
    echo "ALBUM_URL=\\"$ALBUM_URL\\"" >> /tmp/secrets_bak.sh
fi
mv /tmp/secrets_bak.sh /mnt/us/extensions/onlinescreensaver/bin/secrets.sh

# Now run the new 5.0-local update!
sh /mnt/us/extensions/onlinescreensaver/bin/update.sh
"""

stdin, stdout, stderr = client.exec_command(cmd)
print(stdout.read().decode('utf-8'))
for ln in stderr.read().decode('utf-8').split('\n'):
    print('ERR:', ln)
client.close()
