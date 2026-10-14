#!/usr/bin/env bash
# Run as root in a disposable lab cluster only. Needs internet access.
set -euo pipefail

if [ -z "${KUBECONFIG:-}" ]; then
  for f in /etc/rancher/k3s/k3s.yaml /etc/kubernetes/admin.conf; do
    [ -r "$f" ] && export KUBECONFIG=$f && break
  done
fi

[ "$(id -u)" -eq 0 ] || { echo "Run as root." >&2; exit 1; }
command -v kubectl >/dev/null || { echo "kubectl not found." >&2; exit 1; }
if kubectl get namespace shop >/dev/null 2>&1; then
  echo "Already injected. Run reset.sh first." >&2
  exit 1
fi

kubectl apply -f - <<'YAML' >/dev/null
apiVersion: v1
kind: Namespace
metadata:
  name: shop
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: shop
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /
            port: 80
          periodSeconds: 3
---
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: shop
spec:
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 8080
YAML

kubectl -n shop rollout status deploy/web --timeout=180s >/dev/null
echo "Injected."