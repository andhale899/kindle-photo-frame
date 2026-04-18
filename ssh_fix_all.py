import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('192.168.29.76', username='root', password='mario', timeout=10)

def run(cmd, show=True):
    stdin, stdout, stderr = client.exec_command(cmd)
    out = stdout.read().decode('utf-8', errors='replace').strip()
    err = stderr.read().decode('utf-8', errors='replace').strip()
    if show:
        if out: print(out)
        if err and 'Total' not in err and '%' not in err: print('ERR:', err[:300])
    return out, err

BINDIR = '/mnt/us/extensions/onlinescreensaver/bin'
SS_SRC = '/mnt/us/onlinescreensaver/screensaver'
SS_DST = '/usr/share/blanket/screensaver'
SS_ALT = '/var/local/blanket/screensaver'
VAULT  = '/mnt/us/extensions/onlinescreensaver/vault'

print('='*60)
print('STEP 1: Ensure bind mount is active')
print('='*60)
out, _ = run(f'grep "{SS_DST}" /proc/mounts 2>&1')
if SS_DST in out:
    print('Already mounted!')
else:
    run(f'mount --bind "{SS_SRC}" "{SS_DST}"')
    print('Bind mount applied.')

# Also mount alt dir
out2, _ = run(f'grep "{SS_ALT}" /proc/mounts 2>&1', show=False)
if SS_ALT not in out2:
    run(f'[ -d "{SS_ALT}" ] && mount --bind "{SS_SRC}" "{SS_ALT}" 2>/dev/null && echo "Alt mount applied" || echo "Alt dir not present"')

print()
print('='*60)
print('STEP 2: Hotfix process_local.sh (noexec + /tmp bypass)')
print('='*60)
run(f"""
curl -H 'Cache-Control: no-cache' -sL \
  https://raw.githubusercontent.com/andhale899/kindle-photo-frame/kindle-local-only-main/onlinescreensaver/bin/process_local.sh \
  -o /tmp/pl_new.sh
sed -i 's/\r$//' /tmp/pl_new.sh
mv /tmp/pl_new.sh {BINDIR}/process_local.sh
chmod +x {BINDIR}/process_local.sh
echo "process_local.sh updated"
""")

print()
print('='*60)
print('STEP 3: Pre-stage convert to /tmp/kpf_bin (noexec bypass)')
print('='*60)
run(f"""
mkdir -p /tmp/kpf_bin/libs
cp {BINDIR}/convert /tmp/kpf_bin/
cp {BINDIR}/libs/*.so* /tmp/kpf_bin/libs/ 2>/dev/null || true
cp -r {BINDIR}/libs/ImageMagick-7 /tmp/kpf_bin/libs/ 2>/dev/null || true
cp {BINDIR}/libs/ld-musl-armhf.so.1 /tmp/kpf_bin/libs/
chmod +x /tmp/kpf_bin/convert
chmod +x /tmp/kpf_bin/libs/ld-musl-armhf.so.1
echo "Convert staged to /tmp/kpf_bin"
LD_LIBRARY_PATH=/tmp/kpf_bin/libs MAGICK_HOME=/tmp/kpf_bin MAGICK_CONFIGURE_PATH=/tmp/kpf_bin/libs \
  /tmp/kpf_bin/libs/ld-musl-armhf.so.1 /tmp/kpf_bin/convert --version 2>&1 | head -1
""")

print()
print('='*60)
print('STEP 4: Run full update cycle (fetch + overlay + carousel)')
print('='*60)
stdin, stdout, stderr = client.exec_command(f'cd {BINDIR} && sh update.sh')
for line in stdout:
    print(' ', line.rstrip())

print()
print('='*60)
print('STEP 5: Verify screensaver dir has real photos now')
print('='*60)
run(f'ls -lh {SS_SRC}/ | head -6')
run(f'ls -lh {SS_DST}/ | head -3')
run(f'grep screensaver /proc/mounts')

print()
print('='*60)
print('STEP 6: Force screensaver refresh if currently showing')
print('='*60)
run(f"""
lipc-set-prop com.lab126.blanket unload 1 2>/dev/null
sleep 1
lipc-set-prop com.lab126.blanket load 1 2>/dev/null
echo "Blanket reloaded"
""")

client.close()
print()
print('Done! Lock your Kindle screen now to see your photos.')
