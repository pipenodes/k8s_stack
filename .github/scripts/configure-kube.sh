#!/usr/bin/env bash
# Configura kubeconfig. Uso: configure-kube.sh <provider> [clusterName]
# eks: clusterName + AWS_DEFAULT_REGION
# k3s: env KUBE_CONFIG = conteúdo YAML do kubeconfig (secret GitHub KUBECONFIG → env KUBE_CONFIG no workflow)
#     NÃO uses a env KUBECONFIG para o conteúdo: é o nome reservado para caminho(s) de ficheiro (kubectl/helm).
set -euo pipefail
PROVIDER="${1:?}"

case "$PROVIDER" in
  eks)
    CLUSTER_NAME="${2:?}"
    REGION="${AWS_DEFAULT_REGION:?}"
    aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${REGION}"
    ;;
  k3s)
    if [ -z "${KUBE_CONFIG:-}" ]; then
      echo "KUBE_CONFIG is required for k3s provider (kubeconfig YAML from GitHub secret; map secrets.KUBECONFIG to env KUBE_CONFIG)" >&2
      exit 1
    fi
    TMP="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/kubeconfig-$$"
    printf '%s\n' "${KUBE_CONFIG}" > "${TMP}"
    chmod 600 "${TMP}"
    ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
    printf '%s' "${TMP}" > "${ROOT}/.ci-kubeconfig-path"
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
