#!/usr/bin/env bash
# Usage: deploy-cronjobs.sh <development|production>
# Aplica todos os manifests; exit 1 no final se algum falhou.
set -euo pipefail
ENV_DIR="${1:?}"
ROOT="${GITHUB_WORKSPACE:-$(pwd)}"

cd "${ROOT}/${ENV_DIR}/cron-jobs"

failures=0
failed_items=()

for path in *; do
  if [ -f "$path" ] && [[ "$path" == *.yaml ]]; then
    echo "Applying manifest file: $path"
    if ! kubectl apply -f "$path"; then
      failures=$((failures + 1))
      failed_items+=("file:${path}")
      echo "Error: failed to apply $path" >&2
    fi
  elif [ -d "$path" ]; then
    echo "Applying manifests in folder: $path"
    if ! kubectl apply -f "$path"; then
      failures=$((failures + 1))
      failed_items+=("dir:${path}")
      echo "Error: failed to apply manifests in $path" >&2
    fi
  fi
done

if [ "$failures" -gt 0 ]; then
  echo "Cron deploy finished with ${failures} failure(s): ${failed_items[*]}" >&2
  exit 1
fi
