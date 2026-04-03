#!/usr/bin/env bash
# CRDs do CockroachDB operator; aplicar antes do release cockroachdb.
set -euo pipefail
REF="${CRDB_OPERATOR_CRD_REF:-master}"
BASE="https://raw.githubusercontent.com/cockroachdb/cockroach-operator/${REF}/config/crd/bases"
CRD_URL="${BASE}/crdb.cockroachlabs.com_crdbclusters.yaml"
echo "Applying CockroachDB operator CRD: ${CRD_URL}"
kubectl apply -f "${CRD_URL}"