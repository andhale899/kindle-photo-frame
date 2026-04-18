import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('192.168.29.76', username='root', password='mario', timeout=10)

BINDIR = '/mnt/us/extensions/onlinescreensaver/bin'
MUSLD  = f'{BINDIR}/libs/ld-musl-armhf.so.1'

# Test: invoke the convert binary via the bundled musl loader
print('=== Testing convert via musl loader ===')
cmd = (
    f'LD_LIBRARY_PATH={BINDIR}/libs '
    f'MAGICK_HOME={BINDIR} '
    f'MAGICK_CONFIGURE_PATH={BINDIR}/libs '
    f'{MUSLD} {BINDIR}/convert --version 2>&1'
)
stdin, stdout, stderr = client.exec_command(cmd)
out = stdout.read().decode('utf-8', errors='replace')
err = stderr.read().decode('utf-8', errors='replace')
print(out if out else '(no output)')
if err: print('ERR:', err)

client.close()
