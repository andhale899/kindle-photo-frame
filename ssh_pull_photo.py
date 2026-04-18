import paramiko
import os

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('192.168.29.76', username='root', password='mario', timeout=10)

# Download photo_01.png from vault to inspect it locally
os.makedirs('test_output', exist_ok=True)
print('Downloading photo_01.png from Kindle vault...')
sftp = client.open_sftp()
sftp.get('/mnt/us/extensions/onlinescreensaver/vault/photo_01.png', 'test_output/kindle_vault_photo01.png')
sftp.close()

size = os.path.getsize('test_output/kindle_vault_photo01.png')
print(f'Downloaded: {size//1024} KB')
print('Opening image...')
client.close()
