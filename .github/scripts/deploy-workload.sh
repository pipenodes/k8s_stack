#!/usr/bin/env bash
# Deploy apps under <repoPath>/<workload>/ com namespace <repoPath>-<workload>
# Opcional: merge config/helm-overrides/topology-<standalone|clustered>.yaml (via workload-topology.yaml)
# Correr todos os charts/manifests; exit 1 no final se algum falhou.
# Uso: deploy-workload.sh <development|staging|production> <workload-common|workload-vault|workload-obs> <values-*.yaml>
set -euo pipefail
ENV_DIR="${1:?}"
WORKLOAD="${2:?}"
VALUES_FILE="${3:?}"
ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
NAMESPACE="${ENV_DIR}-${WORKLOAD}"
TOPOLOGY_MAP="${ROOT}/config/workload-topology.yaml"

cd "${ROOT}/${ENV_DIR}/${WORKLOAD}"

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

helm_topology_args=()
if [ -f "${TOPOLOGY_MAP}" ] && command -v yq >/dev/null 2>&1; then
  MODE=$(yq -r ".environments.${ENV_DIR}.topology.deploymentMode // \"standalone\"" "${TOPOLOGY_MAP}")
  OVR="${ROOT}/config/helm-overrides/topology-${MODE}.yaml"
  if [ -f "${OVR}" ]; then
    helm_topology_args+=(-f "${OVR}")
  fi
fi

failures=0
failed_items=()

for application_folder_name in */; do
  basename_application_folder=$(basename "$application_folder_name")
  if [ -f "$basename_application_folder/Chart.yaml" ]; then
    if [ "$basename_application_folder" = "traefik" ] && [ "${KUBE_PROVIDER:-}" = "k3s" ]; then
      echo "Skipping Helm chart traefik (KUBE_PROVIDER=k3s: usar Traefik nativo do K3s)."
      continue
    fi
    echo "Deploying Helm chart: $basename_application_folder into namespace ${NAMESPACE}"
    helm_extra_args=()
    if [ "$basename_application_folder" = "cockroachdb" ]; then
      bash "${ROOT}/.github/scripts/apply-crdb-operator-crds.sh"
      helm_extra_args+=(--timeout 25m)
    fi
    # shellcheck disable=SC2086
    if ! helm upgrade --install "$basename_application_folder" "./$application_folder_name" \
      -n "${NAMESPACE}" \
      --create-namespace \
      -f "$basename_application_folder/${VALUES_FILE}" \
      "${helm_topology_args[@]}" \
      "${helm_extra_args[@]}"; then
      failures=$((failures + 1))
      failed_items+=("helm:${basename_application_folder}")
      echo "Error: failed to deploy Helm chart ${basename_application_folder}" >&2
    fi
  else
    if ! kubectl apply -f "$basename_application_folder"; then
      failures=$((failures + 1))
      failed_items+=("kubectl:${basename_application_folder}")
      echo "Error: failed to apply manifests in ${basename_application_folder}" >&2
    fi
  fi
done

if [ "$failures" -gt 0 ]; then
  echo "Deploy finished with ${failures} failure(s): ${failed_items[*]}" >&2
  exit 1
fi