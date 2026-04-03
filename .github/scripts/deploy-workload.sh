#!/usr/bin/env bash
# Deploy apps under <repoPath>/<workload>/ com namespace <repoPath>-<workload>
# Opcional: merge config/helm-overrides/topology-<standalone|clustered>.yaml (via workload-topology.yaml)
# Uso: deploy-workload.sh <development|staging|production> <workload-common|workload-vault|workload-obs> <values-*.yaml>
set -u
ENV_DIR="${1:?}"
WORKLOAD="${2:?}"
VALUES_FILE="${3:?}"
ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
NAMESPACE="${ENV_DIR}-${WORKLOAD}"
TOPOLOGY_MAP="${ROOT}/config/workload-topology.yaml"

cd "${ROOT}/${ENV_DIR}/${WORKLOAD}" || exit 1

helm_topology_args=()
if [ -f "${TOPOLOGY_MAP}" ] && command -v yq >/dev/null 2>&1; then
  MODE=$(yq -r ".environments.${ENV_DIR}.topology.deploymentMode // \"standalone\"" "${TOPOLOGY_MAP}")
  OVR="${ROOT}/config/helm-overrides/topology-${MODE}.yaml"
  if [ -f "${OVR}" ]; then
    helm_topology_args+=(-f "${OVR}")
  fi
fi

for application_folder_name in */; do
  basename_application_folder=$(basename "$application_folder_name")
  if [ -f "$basename_application_folder/Chart.yaml" ]; then
    echo "Deploying Helm chart: $basename_application_folder into namespace ${NAMESPACE}"
    # shellcheck disable=SC2086
    helm upgrade --install "$basename_application_folder" "./$application_folder_name" \
      -n "${NAMESPACE}" \
      --create-namespace \
      -f "$basename_application_folder/${VALUES_FILE}" \
      "${helm_topology_args[@]}" || echo "Warning: failed to deploy $basename_application_folder."
  else
    kubectl apply -f "$basename_application_folder" || echo "Warning: failed to deploy $basename_application_folder."
  fi
done
