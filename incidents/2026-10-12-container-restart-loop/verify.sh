#!/usr/bin/env bash
set -uo pipefail
N=orders-api
fail=0

if ! docker inspect "$N" >/dev/null 2>&1; then
  echo "FAIL container $N not found"; exit 1
fi

running=$(docker inspect -f '{{.State.Running}}' "$N")
oom=$(docker inspect -f '{{.State.OOMKilled}}' "$N")
started=$(docker inspect -f '{{.State.StartedAt}}' "$N")
up=$(( $(date +%s) - $(date -d "$started" +%s) ))

if [ "$running" = true ]; then echo "PASS running"; else echo "FAIL not running"; fail=1; fi
if [ "$oom" = false ]; then echo "PASS not OOM killed"; else echo "FAIL last run was OOM killed"; fail=1; fi
if [ "$up" -ge 45 ]; then echo "PASS up for ${up}s"; else echo "FAIL up only ${up}s, wait and re-run"; fail=1; fi
exit $fail