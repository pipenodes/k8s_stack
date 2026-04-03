#!/usr/bin/env bash
# Depois de configure-kube.sh (k3s): exporta KUBECONFIG para o ficheiro temporário.
# Destina-se a ser executado com: source .github/scripts/apply-kubeconfig-env.sh
# (sem set -u/-e para não alterar o shell do run do Actions.)
ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
PATHFILE="${ROOT}/.ci-kubeconfig-path"
if [ -f "${PATHFILE}" ]; then
  export KUBECONFIG="$(tr -d '\r' < "${PATHFILE}")"
  rm -f "${PATHFILE}"
fi
