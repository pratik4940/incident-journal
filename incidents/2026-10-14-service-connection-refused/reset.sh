#!/usr/bin/env bash
set -uo pipefail

if [ -z "${KUBECONFIG:-}" ]; then
  for f in /etc/rancher/k3s/k3s.yaml /etc/kubernetes/admin.conf; do
    [ -r "$f" ] && export KUBECONFIG=$f && break
  done
fi

[ "$(id -u)" -eq 0 ] || { echo "Run as root." >&2; exit 1; }
kubectl delete namespace shop --ignore-not-found >/dev/null 2>&1
echo "Reset."