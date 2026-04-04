# Observabilidade (movida)

Os charts Helm deste workload estão **deduplicados** em [`observability/workload-obs/`](../../observability/workload-obs/).

O CI faz deploy a partir desse caminho para o namespace definido em `config/cluster-map.yaml` (`clusters.*.observability.namespace`), com `values-development.yaml` ou `values-production.yaml` conforme o cluster.

Não adicionar charts aqui — editar apenas em `observability/workload-obs/`.
