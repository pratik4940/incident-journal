#!/usr/bin/env bash
set -uo pipefail

if [ -z "${KUBECONFIG:-}" ]; then
  for f in /etc/rancher/k3s/k3s.yaml /etc/kubernetes/admin.conf; do
    [ -r "$f" ] && export KUBECONFIG=$f && break
  done
fi

fail=0

ready=$(kubectl -n shop get deploy web -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [ "${ready:-0}" -ge 2 ]; then echo "PASS 2 pods ready"; else echo "FAIL pods not ready"; fail=1; fi

eps=$(kubectl -n shop get endpoints web -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null)
if [ -n "$eps" ]; then echo "PASS service has endpoints"; else echo "FAIL service has no endpoints"; fail=1; fi

out=$(kubectl -n shop run "verify-$RANDOM" --rm -i --restart=Never --pod-running-timeout=90s \
  --image=busybox:1.36 -- wget -qO- -T 3 http://web 2>/dev/null)
if echo "$out" | grep -q "Welcome to nginx"; then
  echo "PASS request to the service succeeds"
else
  echo "FAIL request to the service fails"; fail=1
fi
exit $fail