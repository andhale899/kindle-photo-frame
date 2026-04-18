import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('192.168.29.76', username='root', password='mario', timeout=10)

BINDIR = '/mnt/us/extensions/onlinescreensaver/bin'

# 1. Check convert binary details
print('=== convert binary info ===')
stdin, stdout, stderr = client.exec_command(f'file {BINDIR}/convert 2>&1; ls -lh {BINDIR}/convert 2>&1')
print(stdout.read().decode('utf-8', errors='replace'))

# 2. Check the libs
print('=== libs/ contents ===')
stdin, stdout, stderr = client.exec_command(f'ls -lh {BINDIR}/libs/')
print(stdout.read().decode('utf-8', errors='replace'))

# 3. Try running convert with explicit library path
print('=== Testing convert directly ===')
cmd = (
    f'LD_LIBRARY_PATH={BINDIR}/libs '
    f'MAGICK_HOME={BINDIR} '
    f'MAGICK_CONFIGURE_PATH={BINDIR}/libs '
    f'{BINDIR}/convert --version 2>&1'
)
stdin, stdout, stderr = client.exec_command(cmd)
out = stdout.read().decode('utf-8', errors='replace')
err = stderr.read().decode('utf-8', errors='replace')
print(out if out else '(no stdout)')
if err: print('ERR:', err)

# 4. Check Kindle arch
print('=== Kindle CPU arch ===')
stdin, stdout, stderr = client.exec_command('uname -m; cat /proc/cpuinfo | head -5')
print(stdout.read().decode('utf-8', errors='replace'))

client.close()
