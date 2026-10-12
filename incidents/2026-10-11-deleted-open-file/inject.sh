#!/usr/bin/env bash
# Run as root in a disposable VM only.
set -euo pipefail

MNT=/srv/applogs
IMG=/var/lib/applogs.img
AGENT=/usr/local/bin/metrics-agent

[ "$(id -u)" -eq 0 ] || { echo "Run as root." >&2; exit 1; }
if mountpoint -q "$MNT" || [ -e "$IMG" ] || [ -e "$AGENT" ]; then
  echo "Already injected. Run reset.sh first." >&2
  exit 1
fi

mkdir -p "$MNT"
truncate -s 256M "$IMG"
mkfs.ext4 -q -m 0 -F "$IMG"
mount -o loop "$IMG" "$MNT"

cat > "$AGENT" <<'PY'
#!/usr/bin/env python3
import os, time
p = "/srv/applogs/agent.log"
fd = os.open(p, os.O_WRONLY | os.O_CREAT | os.O_APPEND)
for size in (1048576, 65536, 4096, 512, 1):
    buf = b"x" * size
    try:
        while True:
            os.write(fd, buf)
    except OSError:
        pass
for _ in range(50):
    st = os.statvfs("/srv/applogs")
    free = st.f_bavail * st.f_frsize
    if free < 4096:
        break
    try:
        os.posix_fallocate(fd, os.fstat(fd).st_size, free)
    except OSError:
        try:
            os.posix_fallocate(fd, os.fstat(fd).st_size,
                               max(free // 2 // 4096 * 4096, 4096))
        except OSError:
            pass
os.unlink(p)
while True:
    try:
        os.write(fd, b"heartbeat\n")
    except OSError:
        pass
    time.sleep(5)
PY
chmod +x "$AGENT"
setsid nohup "$AGENT" </dev/null >/dev/null 2>&1 &

for _ in $(seq 1 60); do
  avail=$(df --output=avail -B1 "$MNT" | tail -1 | tr -d ' ')
  if [ "$avail" = "0" ] && [ ! -e "$MNT/agent.log" ]; then
    echo "Injected."
    exit 0
  fi
  sleep 1
done
echo "Injection failed. Run reset.sh and retry." >&2
exit 1