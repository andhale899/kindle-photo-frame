import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('192.168.29.76', username='root', password='mario', timeout=10)

def run(cmd, show=True):
    stdin, stdout, stderr = client.exec_command(cmd)
    out = stdout.read().decode('utf-8', errors='replace').strip()
    err = stderr.read().decode('utf-8', errors='replace').strip()
    if show and out: print(out)
    if show and err: print('ERR:', err[:200])
    return out, err

# ── 1. Find the real screensaver directory on this Kindle ────────────────────
print('=== Finding real screensaver dir ===')
out, _ = run('find /usr/share /var/local -name "*.png" -path "*screensaver*" 2>/dev/null | head -5')
out2, _ = run('ls /usr/share/blanket/screensaver/ 2>&1 | head -3')
out3, _ = run('ls /var/local/screensavers/ 2>&1 | head -3')
out4, _ = run('cat /proc/mounts | grep -i screen 2>&1')

print()
print('=== Fix 1: Copy vault photos directly to the screensaver dir ===')
# The screensaver folder at /mnt/us/onlinescreensaver/screensaver has 14-byte stubs.
# Kill those and copy real vault images over all slots.
fix1 = """
VAULT=/mnt/us/extensions/onlinescreensaver/vault
SS=/mnt/us/onlinescreensaver/screensaver

echo "Clearing old screensaver stubs..."
rm -f $SS/*.png

echo "Copying vault photos to screensaver folder..."
IDX=0
for f in $VAULT/photo_*.png; do
    cp "$f" "$SS/bg_ss$(printf '%02d' $IDX).png"
    cp "$f" "$SS/bg_large_ss$(printf '%02d' $IDX).png"
    cp "$f" "$SS/bg_medium_ss$(printf '%02d' $IDX).png"
    IDX=$((IDX+1))
done
cp $VAULT/photo_01.png $SS/bg_ss.png

echo "Done. Screensaver folder:"
ls -lh $SS | head -5
"""
run(fix1)

print()
print('=== Fix 2: Find and do the bind mount correctly ===')
# Check where the Kindle actually looks for screensavers
run('find /usr /var -type d -name "screensaver" 2>/dev/null')

print()
print('=== Fix 3: Copy libs to /tmp so noexec on /mnt/base-us is bypassed ===')
# /mnt/base-us is noexec. Copy libs + convert to /tmp (which is exec)
# This lets the convert binary actually execute
fix3 = """
echo "Copying convert + libs to /tmp/kpf_bin/ (tmp is exec, mnt/base-us is noexec)..."
mkdir -p /tmp/kpf_bin/libs
cp /mnt/us/extensions/onlinescreensaver/bin/convert /tmp/kpf_bin/
cp /mnt/us/extensions/onlinescreensaver/bin/libs/*.so* /tmp/kpf_bin/libs/
cp -r /mnt/us/extensions/onlinescreensaver/bin/libs/ImageMagick-7 /tmp/kpf_bin/libs/ 2>/dev/null || true
cp /mnt/us/extensions/onlinescreensaver/bin/libs/ld-musl-armhf.so.1 /tmp/kpf_bin/libs/
chmod +x /tmp/kpf_bin/convert
chmod +x /tmp/kpf_bin/libs/ld-musl-armhf.so.1
echo "Testing convert from /tmp/kpf_bin..."
LD_LIBRARY_PATH=/tmp/kpf_bin/libs MAGICK_HOME=/tmp/kpf_bin MAGICK_CONFIGURE_PATH=/tmp/kpf_bin/libs \
  /tmp/kpf_bin/libs/ld-musl-armhf.so.1 /tmp/kpf_bin/convert --version 2>&1 | head -1
"""
run(fix3)

print()
print('=== Fix 4: Bind mount — find real screensaver target ===')
out, _ = run('ls /usr/share/blanket/ 2>&1')
print('blanket contents:', out)
out, _ = run('cat /proc/mounts | grep blanket 2>&1')
print('blanket mounts:', out or 'none')

# Try the bind mount now
run("""
SS_SRC=/mnt/us/onlinescreensaver/screensaver
SS_DEST=/usr/share/blanket/screensaver
if [ -d "$SS_DEST" ]; then
    if ! grep -q " $SS_DEST " /proc/mounts; then
        mount --bind "$SS_SRC" "$SS_DEST"
        echo "Bind mount applied: $SS_SRC -> $SS_DEST"
        grep screensaver /proc/mounts
    else
        echo "Already mounted"
    fi
else
    echo "DEST $SS_DEST does not exist — trying alternative..."
    find /usr /var -type d -name "screensaver" 2>/dev/null
fi
""")

client.close()
print('\n=== Diagnosis complete ===')
