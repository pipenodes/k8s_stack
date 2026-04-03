#!/usr/bin/env bash
# Usage: deploy-cronjobs.sh <development|production>
set -u
ENV_DIR="${1:?}"
ROOT="${GITHUB_WORKSPACE:-$(pwd)}"

cd "${ROOT}/${ENV_DIR}/cron-jobs" || exit 1
for path in *; do
  if [ -f "$path" ] && [[ "$path" == *.yaml ]]; then
    echo "Applying manifest file: $path"
    kubectl apply -f "$path" || echo "Warning: failed to apply $path."
  elif [ -d "$path" ]; then
    echo "Applying manifests in folder: $path"
    kubectl apply -f "$path" || echo "Warning: failed to apply manifests in $path."
  fi
done
