#!/usr/bin/env bash
# Atualiza todos os deploy.ack em development/ e production/ com timestamp ISO 8601 em UTC.
# Formato por defeito: YYYY-MM-DDTHH:MM:SSZ (ex.: 2026-04-03T18:45:00Z)
# Uso: bump-deploy-ack.sh [valor]
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "${ROOT}" ]; then
  ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fi
VAL="${1:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
write_ack() {
  local f="$1"
  printf '%s\n' "${VAL}" >"${f}"
  echo "  ${f}"
}
echo "deploy.ack <- ${VAL}"
for env in development production; do
  env_dir="${ROOT}/${env}"
  [ -d "${env_dir}" ] || continue
  write_ack "${env_dir}/deploy.ack"
  if [ -d "${env_dir}/cron-jobs" ]; then
    write_ack "${env_dir}/cron-jobs/deploy.ack"
  fi
  for wl in workload-common workload-vault workload-obs; do
    wl_dir="${env_dir}/${wl}"
    [ -d "${wl_dir}" ] || continue
    write_ack "${wl_dir}/deploy.ack"
    for appdir in "${wl_dir}"/*/; do
      [ -d "${appdir}" ] || continue
      write_ack "${appdir}deploy.ack"
    done
  done
done
echo "Feito."