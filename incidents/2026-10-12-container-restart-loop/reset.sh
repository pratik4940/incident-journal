#!/usr/bin/env bash
set -uo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Run as root." >&2; exit 1; }
docker rm -f orders-api >/dev/null 2>&1 || true
rm -rf /opt/orders-api
echo "Reset."