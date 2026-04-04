#!/usr/bin/env bash
# Carrega variaveis a partir de config/cluster-map.yaml e config/workload-topology.yaml (requer yq).
# Uso: load-cluster-env.sh <development|staging|production>
set -euo pipefail
ENV_NAME="${1:?}"
ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
MAP="${ROOT}/config/cluster-map.yaml"
TOPOLOGY="${ROOT}/config/workload-topology.yaml"

if [ ! -f "${MAP}" ]; then
  echo "Missing ${MAP}" >&2
  exit 1
fi

CLUSTER_REF=$(yq -r ".environments.${ENV_NAME}.clusterRef" "${MAP}")
PROVIDER=$(yq -r ".clusters.${CLUSTER_REF}.provider" "${MAP}")
echo "CLUSTER_REF=${CLUSTER_REF}" >> "${GITHUB_ENV}"
echo "KUBE_PROVIDER=${PROVIDER}" >> "${GITHUB_ENV}"

case "${PROVIDER}" in
  eks)
    CN=$(yq -r ".clusters.${CLUSTER_REF}.eks.clusterName" "${MAP}")
    echo "EKS_CLUSTER_NAME=${CN}" >> "${GITHUB_ENV}"
    ;;
  k3s)
    # Secret GitHub KUBECONFIG → env KUBE_CONFIG no workflow (conteúdo); configure-kube grava ficheiro e exporta KUBECONFIG=path
    ;;
esac

# Observabilidade deduplicada (observability/workload-obs): namespace + quem pode fazer deploy no CI
OBS_NS=$(yq -r "(.clusters.${CLUSTER_REF}.observability // {}).namespace // \"\"" "${MAP}")
if [ -n "${OBS_NS}" ] && [ "${OBS_NS}" != "null" ]; then
  echo "OBS_NAMESPACE=${OBS_NS}" >> "${GITHUB_ENV}"
fi
LEN=$(yq "(.clusters.${CLUSTER_REF}.observability // {}).deployForEnvironments // [] | length" "${MAP}")
if [ "${LEN}" = "0" ]; then
  echo "SKIP_WORKLOAD_OBS=0" >> "${GITHUB_ENV}"
else
  if yq -e "(.clusters.${CLUSTER_REF}.observability // {}).deployForEnvironments[] | select(. == \"${ENV_NAME}\")" "${MAP}" >/dev/null 2>&1; then
    echo "SKIP_WORKLOAD_OBS=0" >> "${GITHUB_ENV}"
  else
    echo "SKIP_WORKLOAD_OBS=1" >> "${GITHUB_ENV}"
  fi
fi

if [ -f "${TOPOLOGY}" ]; then
  MODE=$(yq -r ".environments.${ENV_NAME}.topology.deploymentMode // \"standalone\"" "${TOPOLOGY}")
  AFF=$(yq -r ".environments.${ENV_NAME}.topology.nodeAffinity // \"disabled\"" "${TOPOLOGY}")
  echo "TOPOLOGY_MODE=${MODE}" >> "${GITHUB_ENV}"
  echo "NODE_AFFINITY=${AFF}" >> "${GITHUB_ENV}"
fi
