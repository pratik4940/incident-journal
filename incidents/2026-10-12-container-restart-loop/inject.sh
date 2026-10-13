#!/usr/bin/env bash
# Run as root in a disposable VM only. Needs Docker and internet access.
set -euo pipefail

APP=/opt/orders-api

[ "$(id -u)" -eq 0 ] || { echo "Run as root." >&2; exit 1; }
command -v docker >/dev/null || { echo "Docker is not installed." >&2; exit 1; }
if docker ps -a --format '{{.Names}}' | grep -qx orders-api; then
  echo "Already injected. Run reset.sh first." >&2
  exit 1
fi

mkdir -p "$APP"
cat > "$APP/app.py" <<'PY'
import time

cache = []
print("orders-api starting", flush=True)
while True:
    if len(cache) < 20:
        cache.append(b"x" * (8 * 1024 * 1024))
    print(f"ok cache={len(cache) * 8}MB", flush=True)
    time.sleep(1)
PY

docker pull -q python:3.12-alpine >/dev/null
docker run -d --name orders-api --restart unless-stopped \
  --memory 64m --memory-swap 64m \
  -v "$APP":/app:ro \
  python:3.12-alpine python -u /app/app.py >/dev/null
echo "Injected."