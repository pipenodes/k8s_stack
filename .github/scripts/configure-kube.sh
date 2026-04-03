#!/usr/bin/env bash
# Configura kubeconfig. Uso: configure-kube.sh <provider> [clusterName]
# eks: clusterName + AWS_DEFAULT_REGION; k3s: env KUBECONFIG (kubeconfig em base64) → ficheiro + export KUBECONFIG=caminho
set -euo pipefail
PROVIDER="${1:?}"

case "$PROVIDER" in
  eks)
    CLUSTER_NAME="${2:?}"
    REGION="${AWS_DEFAULT_REGION:?}"
    aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${REGION}"
    ;;
  k3s)
    if [ -z "${KUBECONFIG:-}" ]; then
      echo "KUBECONFIG is required for k3s provider (kubeconfig content, base64-encoded)" >&2
      exit 1
    fi
    KUBECONFIG_INPUT="${KUBECONFIG}"
    TMP="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/kubeconfig-$$"
    echo "${KUBECONFIG_INPUT}" | base64 -d > "${TMP}"
    chmod 600 "${TMP}"
    if [ -n "${GITHUB_ENV:-}" ]; then
      echo "KUBECONFIG=${TMP}" >> "${GITHUB_ENV}"
    fi
    export KUBECONFIG="${TMP}"
    ;;
  aks|gke|oke)
    echo "Provider '${PROVIDER}' ainda nao implementado em configure-kube.sh" >&2
    exit 1
    ;;
  *)
    echo "Unknown provider: ${PROVIDER}" >&2
    exit 1
    ;;
esac
