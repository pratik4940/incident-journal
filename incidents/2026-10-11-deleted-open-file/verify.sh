#!/usr/bin/env bash
set -uo pipefail
MNT=/srv/applogs
fail=0

if pgrep -f '^python3 /usr/local/bin/metrics-agent' >/dev/null; then
  echo "PASS agent still running"
else
  echo "FAIL agent not running"; fail=1
fi

total=$(df --output=size -B1 "$MNT" | tail -1 | tr -d ' ')
avail=$(df --output=avail -B1 "$MNT" | tail -1 | tr -d ' ')
if [ "$avail" -gt $((total / 2)) ]; then
  echo "PASS more than 50% free"
else
  echo "FAIL less than 50% free"; fail=1
fi

if echo ok > "$MNT/.verify" 2>/dev/null; then
  rm -f "$MNT/.verify"
  echo "PASS writes succeed"
else
  echo "FAIL writes fail"; fail=1
fi
exit $fail