#!/usr/bin/env bash
# Garante StorageClass local-path (rancher.io/local-path) em clusters K3s.
set -euo pipefail
if [ "${KUBE_PROVIDER:-}" != "k3s" ]; then
  echo "Skipping local-path StorageClass (KUBE_PROVIDER=${KUBE_PROVIDER:-unset}, only applied for k3s)."
  exit 0
fi
ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
MANIFEST="${ROOT}/config/k8s/storageclass-local-path.yaml"
if [ ! -f "${MANIFEST}" ]; then
  echo "Missing ${MANIFEST}" >&2
  exit 1
fi
kubectl apply -f "${MANIFEST}"