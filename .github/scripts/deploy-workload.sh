#!/usr/bin/env bash
# Deploy apps under <repoPath>/<workload>/ com namespace <repoPath>-<workload>
# Opcional: merge topology-*.yaml; com KUBE_PROVIDER=k3s merge config/helm-overrides/k3s/<chart>.yaml-<standalone|clustered>.yaml (via workload-topology.yaml)
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

# OpenTelemetry (e outros) podem referir <env>-workload-vault antes do passo workload-vault no CI.
if [ "${WORKLOAD}" = "workload-obs" ]; then
  VAULT_NS="${ENV_DIR}-workload-vault"
  kubectl create namespace "${VAULT_NS}" --dry-run=client -o yaml | kubectl apply -f -
fi

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

# workload-obs: kube-prometheus-stack primeiro (CRDs / operator) para charts com ServiceMonitor (ex.: Grafana).
shopt -s nullglob
workload_obs_ordered_dirs() {
  local d
  if [ -d "kube-prometheus-stack" ]; then
    printf '%s\n' "kube-prometheus-stack/"
  fi
  while IFS= read -r d; do
    [ -z "$d" ] && continue
    [ "$d" = "kube-prometheus-stack/" ] && continue
    printf '%s\n' "$d"
  done < <(printf '%s\n' */ | LC_ALL=C sort)
}

if [ "${WORKLOAD}" = "workload-obs" ]; then
  readarray -t obs_dirs < <(workload_obs_ordered_dirs)
  chart_iter=("${obs_dirs[@]}")
else
  chart_iter=(*/)
fi

for application_folder_name in "${chart_iter[@]}"; do
  basename_application_folder=$(basename "$application_folder_name")
  if [ -f "$basename_application_folder/Chart.yaml" ]; then
    if [ "$basename_application_folder" = "traefik" ] && [ "${KUBE_PROVIDER:-}" = "k3s" ]; then
      echo "Skipping Helm chart traefik (KUBE_PROVIDER=k3s: usar Traefik nativo do K3s)."
      continue
    fi
    echo "Deploying Helm chart: $basename_application_folder into namespace ${NAMESPACE}"
    helm_extra_args=()
    helm_k3s_args=()
    if [ "$basename_application_folder" = "cockroachdb" ]; then
      bash "${ROOT}/.github/scripts/apply-crdb-operator-crds.sh"
      helm_extra_args+=(--timeout 25m)
    fi
    if [ "$basename_application_folder" = "kube-prometheus-stack" ]; then
      # Hooks de admission (Jobs patch/cert) em nó único / CPU limitada podem exceder 20m
      helm_extra_args+=(--timeout 35m)
    fi
    if [ "$basename_application_folder" = "jaeger" ]; then
      # post-upgrade: Job schema Cassandra (activeDeadlineSeconds nos values pode ir a 30m)
      helm_extra_args+=(--timeout 35m)
    fi
    if [ "${KUBE_PROVIDER:-}" = "k3s" ] && case "${WORKLOAD}" in workload-obs|workload-vault|workload-common) true ;; *) false ;; esac; then
      K3S_OVR="${ROOT}/config/helm-overrides/k3s/${basename_application_folder}.yaml"
      if [ -f "${K3S_OVR}" ]; then
        helm_k3s_args=(-f "${K3S_OVR}")
      fi
    fi
    # shellcheck disable=SC2086
    if ! helm upgrade --install "$basename_application_folder" "./$application_folder_name" \
      -n "${NAMESPACE}" \
      --create-namespace \
      -f "$basename_application_folder/${VALUES_FILE}" \
      "${helm_topology_args[@]}" \
      "${helm_k3s_args[@]}" \
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