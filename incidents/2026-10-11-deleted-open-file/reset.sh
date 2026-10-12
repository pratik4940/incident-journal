#!/usr/bin/env bash
set -uo pipefail
MNT=/srv/applogs

[ "$(id -u)" -eq 0 ] || { echo "Run as root." >&2; exit 1; }

pkill -f '^python3 /usr/local/bin/metrics-agent' || true
sleep 1
if mountpoint -q "$MNT"; then umount "$MNT" || umount -l "$MNT"; fi
rm -f /var/lib/applogs.img /usr/local/bin/metrics-agent
rmdir "$MNT" 2>/dev/null || true
echo "Reset."