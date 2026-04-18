import paramiko
import time
import urllib.request
import json

KINDLE_IP   = '192.168.29.76'
KINDLE_USER = 'root'
KINDLE_PASS = 'mario'
BINDIR      = '/mnt/us/extensions/onlinescreensaver/bin'
DEST        = '/mnt/us/extensions/onlinescreensaver'

# ────────────────────────────────────────────────────────────────────────────
# 1.  Wait for the latest GitHub Release to contain the musl-loader fix
# ────────────────────────────────────────────────────────────────────────────
print('[1/5] Waiting for GitHub Actions to finish building...')
ZIP_URL = None
for attempt in range(30):          # poll up to 5 minutes
    try:
        req = urllib.request.Request(
            'https://api.github.com/repos/andhale899/kindle-photo-frame/releases/latest',
            headers={'User-Agent': 'Mozilla/5.0'}
        )
        data = json.loads(urllib.request.urlopen(req, timeout=10).read())
        assets = data.get('assets', [])
        if assets:
            ZIP_URL = assets[0]['browser_download_url']
            print(f'      Release ready: {assets[0]["name"]} ({assets[0]["size"]//1024} KB)')
            break
    except Exception as e:
        pass
    print(f'      Attempt {attempt+1}/30 – waiting 10s...', end='\r')
    time.sleep(10)

if not ZIP_URL:
    # fallback – use known-good URL from previous release
    ZIP_URL = 'https://github.com/andhale899/kindle-photo-frame/releases/latest/download/KindlePhotoFrame_5.0-local.zip'
    print(f'      Using fallback URL: {ZIP_URL}')

# ────────────────────────────────────────────────────────────────────────────
# 2.  Connect to Kindle
# ────────────────────────────────────────────────────────────────────────────
print('[2/5] Connecting to Kindle over SSH...')
client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(KINDLE_IP, username=KINDLE_USER, password=KINDLE_PASS, timeout=15)
print('      Connected!')

def run(cmd, label=''):
    stdin, stdout, stderr = client.exec_command(cmd)
    out = stdout.read().decode('utf-8', errors='replace').strip()
    err = stderr.read().decode('utf-8', errors='replace').strip()
    if label and out:
        print(f'      {label}: {out}')
    return out, err

# ────────────────────────────────────────────────────────────────────────────
# 3.  Backup secrets before overwriting
# ────────────────────────────────────────────────────────────────────────────
print('[3/5] Backing up secrets.sh...')
out, _ = run(f'cat {BINDIR}/secrets.sh 2>/dev/null')
old_secrets = out if out else None
if old_secrets:
    print('      secrets.sh backed up to memory.')
else:
    print('      No secrets.sh found – will create fresh from template.')

# ────────────────────────────────────────────────────────────────────────────
# 4.  Download & install the release ZIP
# ────────────────────────────────────────────────────────────────────────────
print(f'[4/5] Installing from: {ZIP_URL}')

install_cmd = f"""
set -e
echo "  Downloading ZIP..."
curl -L -o /tmp/kpf_install.zip '{ZIP_URL}'
echo "  Downloaded $(ls -lh /tmp/kpf_install.zip | awk '{{print $5}}')"

echo "  Extracting to /mnt/us/..."
unzip -o /tmp/kpf_install.zip -d /mnt/us/ 2>&1 | tail -5

echo "  Fixing CRLF line endings..."
for f in {BINDIR}/*.sh; do sed -i 's/\r$//' "$f"; done
sed -i 's/\r$//' {BINDIR}/secrets.sh.template 2>/dev/null || true

echo "  Setting permissions..."
chmod +x {BINDIR}/*.sh
chmod +x {BINDIR}/convert  2>/dev/null || true
chmod +x {BINDIR}/libs/ld-musl-armhf.so.1 2>/dev/null || true
chmod +x {BINDIR}/rtcwake 2>/dev/null || true

echo "  Creating required directories..."
mkdir -p {DEST}/vault
mkdir -p {DEST}/logs
mkdir -p /mnt/us/onlinescreensaver/screensaver

echo "  Install complete!"
"""

stdin, stdout, stderr = client.exec_command(install_cmd)
for line in stdout:
    print(' ', line.rstrip())
for line in stderr:
    l = line.rstrip()
    if l and 'Total' not in l and '%' not in l and 'inflating' not in l:
        print('  ERR:', l)

# ────────────────────────────────────────────────────────────────────────────
# 5.  Restore secrets + add ALBUM_URL if missing
# ────────────────────────────────────────────────────────────────────────────
print('[5/5] Restoring secrets.sh...')
ALBUM_URL = 'https://photos.app.goo.gl/yBPwxSGuEEnwnhGk9'

if old_secrets:
    # Write back the backed-up secrets
    sftp = client.open_sftp()
    secrets_content = old_secrets
    # Inject ALBUM_URL if not already present
    if 'ALBUM_URL' not in secrets_content:
        secrets_content += f'\nALBUM_URL="{ALBUM_URL}"\n'
    with sftp.open(f'{BINDIR}/secrets.sh', 'w') as f:
        f.write(secrets_content + '\n')
    sftp.close()
    print('      secrets.sh restored (with ALBUM_URL).')
else:
    # Create fresh from template, inject ALBUM_URL
    create_cmd = f"""
cp {BINDIR}/secrets.sh.template {BINDIR}/secrets.sh
echo 'ALBUM_URL="{ALBUM_URL}"' >> {BINDIR}/secrets.sh
sed -i 's/\r$//' {BINDIR}/secrets.sh
"""
    run(create_cmd)
    print('      Fresh secrets.sh created from template.')

# ────────────────────────────────────────────────────────────────────────────
# 6.  Test convert binary
# ────────────────────────────────────────────────────────────────────────────
print()
print('[VERIFY] Testing bundled ImageMagick...')
musl   = f'{BINDIR}/libs/ld-musl-armhf.so.1'
conv   = f'{BINDIR}/convert'
out, err = run(
    f'LD_LIBRARY_PATH={BINDIR}/libs MAGICK_HOME={BINDIR} '
    f'MAGICK_CONFIGURE_PATH={BINDIR}/libs '
    f'{musl} {conv} --version 2>&1 | head -1'
)
if 'ImageMagick' in out:
    print(f'      OK: {out}')
else:
    print(f'      FAIL: {out} | {err}')

# ────────────────────────────────────────────────────────────────────────────
# 7.  Run first update cycle
# ────────────────────────────────────────────────────────────────────────────
print()
print('[RUN] Running first update cycle (downloading + embedding photos)...')
stdin, stdout, stderr = client.exec_command(f'cd {BINDIR} && sh update.sh')
for line in stdout:
    print(' ', line.rstrip())

client.close()
print()
print('Done! Installation complete.')
