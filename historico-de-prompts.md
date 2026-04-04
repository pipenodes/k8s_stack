# Histórico de prompts

## 2026-04-03

### Prompt 1

Implementar o plano "Mapa profundo do repositório k8s_stack": alinhar CI às pastas existentes, integrar `workload-api` no GitLab CI, e adicionar README na raiz (sem editar o ficheiro do plano).

**Resultado:** Removidos jobs GitLab para `workload-dlc`, `workload-dlg`, `workload-dli` e `workload-ilum`; adicionados stages e jobs `deployWorkload*Api` para `development/workload-api` e `production/workload-api`; atualizado `.gitlab-ci.yml`. Criados `README.md` e este ficheiro.

### Prompt 2

Renomear `workload-api` para `workload-vault` em todo o projeto e transpor o pipeline `.gitlab-ci` para GitHub Actions.

**Resultado:** Pastas e namespaces atualizados para `workload-vault` (Traefik, Loki, OTEL, Promtail, VSO); jobs GitLab renomeados para `deployWorkload*Vault` e stages `*workload-vault*`. Adicionados `.github/workflows/k8s-deploy.yml` e scripts em `.github/scripts/`. README atualizado para GitHub Actions e secrets.

### Prompt 3

Remover tudo o que é referente a GitLab CI/CD, deixando apenas GitHub Actions.

**Resultado:** Eliminados todos os ficheiros `.gitlab-*.yml`; README e comentário do workflow ajustados para não referenciar GitLab.

### Prompt 4

Substituir `.gitlab-deployment-restart.yml` por equivalente em GitHub Actions para production (e development).

**Resultado:** Criado `.github/workflows/deployment-restart.yml` com `workflow_dispatch` (inputs: environment, deployment_name, namespace); README atualizado com secção "Restart manual de um Deployment".

### Prompt 5

Implementar plano multi-cluster: mapa em `config/`, namespaces `<env>-workload-*`, GitHub Environments, scripts `configure-kube` / `load-cluster-env`, workflows atualizados.

**Resultado:** Adicionados `config/cluster-map.yaml` e `config/github-environments.yaml`; namespaces com prefixo em manifests (script `tools/prefix_namespaces.py`); jobs `deploy-development` e `deploy-production` com `environment`; `deployment-restart` alinhado ao mapa; README atualizado.

### Prompt 6

Plano K3s on‑prem nos três ambientes + topologia (standalone/clustered + node affinity) e credenciais AWS condicionais.

**Resultado:** `cluster-map.yaml` com clusters K3s por ambiente; `workload-topology.yaml` e `helm-overrides/topology-*.yaml`; `load-cluster-env.sh` exporta topologia; `deploy-workload.sh` faz merge Helm opcional; workflows só usam AWS quando `KUBE_PROVIDER=eks`; README atualizado.

### Prompt 7

Redis: development em modo standalone (scheduling leve); produção sem node affinity / anti-affinity presets.

**Resultado:** Ajustados `development/workload-common/redis/values-development.yaml` e `production/workload-common/redis/values-production.yaml` (podAntiAffinityPreset vazio, nodeSelector `{}`, réplica count 1 em dev).

### Prompt 8

Criar pasta `docs/` com documentação HOWTO, Examples e explicação dos overrides de topologia.

**Resultado:** Adicionados `docs/README.md`, `docs/HOWTO.md`, `docs/examples.md`; link no README da raiz; `historico-de-prompts.md` atualizado.

### Prompt 9

Rever README: índice para `docs/`, shields GitHub.

**Resultado:** README com tabela de índice, secção Documentação (`docs/`), badges Actions (shields.io) e badge Docs; nota para ajustar `owner/repo` se necessário.

### Prompt 10

Em todo o projeto, trocar `KUBE_CONFIG_B64` por `KUBECONFIG` apenas.

**Resultado:** Workflows passam `secrets.KUBECONFIG`; `configure-kube.sh` lê base64 de `KUBECONFIG`, grava ficheiro e exporta `KUBECONFIG` para o caminho; `github-environments.yaml`, `cluster-map`, docs e README atualizados. **Ação manual:** renomear o secret no GitHub de `KUBE_CONFIG_B64` para `KUBECONFIG` (ou criar novo e apagar o antigo).

### Prompt 11

Histórico novo: um único commit com estado atual limpo + `git push --force-with-lease`.

**Resultado:** Branch órfã com commit `d818e60`; `main` substitui histórico antigo; push para `origin` concluído (sem push protection por segredos no histórico antigo).

### Prompt 12

Plano: `KUBECONFIG` em texto claro (sem base64 no CI); workflows chamam `configure-kube` com 2 args só para EKS; documentação alinhada.

**Resultado:** `configure-kube.sh` grava YAML direto; README, HOWTO, examples, `github-environments.yaml`; `k8s-deploy.yml` e `deployment-restart.yml` com `if [ KUBE_PROVIDER = eks ]`.

### Prompt 13

Incluir no `workload-common` CockroachDB com Helm + Operator (Cockroach Labs).

**Resultado:** Vendored `cockroachdb-parent` de [cockroachdb/helm-charts](https://github.com/cockroachdb/helm-charts) em `development/workload-common` e `production/workload-common`; `values-development.yaml` e `values-production.yaml` com região `on-prem`, namespaces e storage; README e HOWTO atualizados; `deploy-workload.sh` com `--timeout 25m` para este chart.

### Prompt 14

CI: Helm/kubectl `loading config file` / `file name too long` com kubeconfig no secret.

**Resultado:** Workflows passam o secret para **`KUBE_CONFIG`** (não `KUBECONFIG`); `configure-kube.sh` grava `.ci-kubeconfig-path`; `apply-kubeconfig-env.sh` com `source` exporta `KUBECONFIG` no shell do step; README/docs/github-environments atualizados.

### Prompt 15

CockroachDB `values-*`: StorageClass `local-path` em dev e prod.

**Resultado:** `storageClassName: local-path` em `dataStore.volumeClaimTemplate.spec` nos dois ficheiros.

### Prompt 16

Renomear pastas `cockroachdb-parent` → `cockroachdb` em development e production `workload-common`.

**Resultado:** `git mv` para `workload-common/cockroachdb/`; `deploy-workload.sh` timeout alinhado ao nome `cockroachdb`; README, HOWTO e comentários nos `values-*` atualizados.

### Prompt 17

Adicionar `TS_AUTHKEY` no GitHub e implementar Tailscale nos GitHub Actions.

**Resultado:** Passo `tailscale/github-action@v4` com `authkey: secrets.TS_AUTHKEY` após `load-cluster-env.sh` em `k8s-deploy.yml` (development e production) quando `KUBE_PROVIDER == k3s`; mesmo padrão em `deployment-restart.yml`. Atualizados `config/github-environments.yaml` e README.

### Prompt 18

Erro no CI: `lookup lab.ocicat-lake.ts.net on 127.0.0.53: no such host` apesar de telnet funcionar de outro nó na tailnet.

**Resultado:** README: nota sobre falha de MagicDNS no runner GitHub Actions; workaround `server` com IP Tailscale + `tls-server-name` para validação TLS.

### Prompt 19

Pipeline a marcar sucesso quando Helm/kubectl falhavam (avisos "Warning: failed to deploy").

**Resultado:** `deploy-workload.sh` e `deploy-cronjobs.sh` com `set -euo pipefail` e remoção de `|| echo` que mascarava códigos de saída; qualquer falha de `helm`/`kubectl` falha o job.

### Prompt 20

Acumular falhas nos deploys e só `exit 1` no final (em vez de fail-fast).

**Resultado:** `deploy-workload.sh` e `deploy-cronjobs.sh` contam falhas com `if ! helm`/`if ! kubectl`, listam itens falhados no stderr e terminam com código 1 se `failures > 0`; `cd`/`yq` mantêm `set -e`.

### Prompt 21

CockroachDB: disco 10G em development e production, StorageClass `local-path`.

**Resultado:** `values-production.yaml`: `storage` de `20Gi` para `10Gi`; `values-development.yaml` já estava `10Gi` com `local-path`.

### Prompt 22

Executar plano de deploy: StorageClass `local-path`, ordem obs→vault→common→cron, CRD Cockroach antes do helm, saltar Traefik em K3s, namespace idempotente.

**Resultado:** `config/k8s/storageclass-local-path.yaml`; `ensure-local-path-storageclass.sh`, `apply-crdb-operator-crds.sh`; `deploy-workload.sh` atualizado; `k8s-deploy.yml` reordenado + passo StorageClass (K3s); HOWTO e README atualizados.

### Prompt 23

Criar `deploy.ack` com conteúdo `1` na raiz de `development/` e de `production/`.

**Resultado:** Ficheiros `development/deploy.ack` e `production/deploy.ack`.

### Prompt 24

`deploy.ack` em todas as pastas de deploy em development/production e scripts (PowerShell + shell) para atualizar com data Julian; alternativas documentadas.

**Resultado:** `tools/bump-deploy-ack.sh`, `tools/bump-deploy-ack.ps1`, `tools/README-deploy-ack.md`; todos os `deploy.ack` nas raízes env/cron-jobs/workload-* e em cada app; HOWTO com referência aos scripts.

### Prompt 25

Timestamp nos `deploy.ack`: preferir formato melhor que Julian.

**Resultado:** Valor por defeito nos scripts passou a **ISO 8601 UTC** (`YYYY-MM-DDTHH:MM:SSZ`); README-deploy-ack e HOWTO atualizados; `bump-deploy-ack.ps1` aplicado para alinhar ficheiros `deploy.ack`.

### Prompt 26

Implementar plano "correção deploy workload-obs (EKS)": ordem KPS primeiro, `fullnameOverride` por ambiente, namespace vault na fase obs, documentação.

**Resultado:** `deploy-workload.sh`: `workload-obs` instala `kube-prometheus-stack` antes do resto (restante em ordem `LC_ALL=C`); cria `<env>-workload-vault` idempotente; `kube-prometheus-stack/values-development.yaml` e `values-production.yaml` com `fullnameOverride` distinto; HOWTO §6 e bullets em §1/§3; este registo.

### Prompt 27

Executar plano RBAC multi-env + K3s control-plane: remover `nodeSelector` legados (EKS `ng:*`), overrides `config/helm-overrides/k3s/*.yaml`, merge condicional em `deploy-workload.sh`, nomes únicos Loki/Promtail/OTel, URLs gateway Loki, timeout KPS, documentação.

**Resultado:** Removidos `ng: obs-default-*` / `common-default-*` e tolerations `workload-type` dos `values-*.yaml` afetados; `config/helm-overrides/k3s/` por chart; `deploy-workload.sh` com `-f` K3s e `--timeout 20m` para `kube-prometheus-stack`; `fullnameOverride` Loki/Promtail; `clusterRole` OTel; URLs `*-loki-gateway` em OTel, Promtail e Traefik; HOWTO §7–§8; tabela §3; este registo.

### Prompt 28

Regenerar timestamps em todos os `deploy.ack` (paths-filter) e commit + push.

**Resultado:** `tools/bump-deploy-ack.ps1` (ISO 8601 UTC); `git commit` + `git push` em `main`.

### Prompt 29

Implementar plano "local-path, sem nodeSelector, scheduling no control-plane (affinity)": StorageClass `local-path`, overrides K3s com nodeAffinity, `fullnameOverride` curto no KPS, Jaeger/Cassandra dev e documentação.

**Resultado:** `gp3-default` / `ebs-gp3-sc` → `local-path` em Loki, Thanos, Grafana, Redis (incl. `values.yaml` base), RedisInsight, Jupyter PVC; `config/helm-overrides/k3s/*.yaml` com nodeAffinity + tolerations (Promtail só tolerations); Tempo com affinity em string (tpl); Job schema Jaeger com suporte a `schema.affinity` no template; Cassandra `cluster_size: 1` em dev; KPS `obs-kps-dev` / `obs-kps-prd`; HOWTO §6, §8 e nova §9; este registo.

### Prompt 30

Corrigir falhas de deploy: timeout nos hooks do `kube-prometheus-stack` e Job imutável `jaeger-cassandra-schema` no `helm upgrade`.

**Resultado:** Job Cassandra schema com hooks Helm (`post-install`/`post-upgrade`, `before-hook-creation`); `deploy-workload.sh`: timeout KPS `35m`; HOWTO §3/§9 atualizados; este registo.

### Prompt 31

Executar `bump-deploy-ack`, commit e push; opcionalmente limpar Job Jaeger no cluster.

**Resultado:** `tools/bump-deploy-ack.ps1` (timestamp `2026-04-03T23:20:14Z`); `git commit` + `git push` em `main` (`c97a880`); `kubectl` em context `default` sem Job `jaeger-cassandra-schema` no cluster atual; este registo.

### Prompt 32

Voltar a correr `bump-deploy-ack.ps1`, commit e push.

**Resultado:** Timestamp `2026-04-03T23:33:28Z` em 39 `deploy.ack`; commit `3470dd5` + push `main`; este registo.

### Prompt 33

Implementar plano "local-path em todo o lado (dev + prod) + auditoria": OTel sem âncoras raiz, `local-path` explícito em Redis/Traefik/Tempo/Vault, inlinar todos os `helm-overrides/k3s/*.yaml`, HOWTO §10 e validação.

**Resultado:** `opentelemetry-collector.yaml` e restantes K3s sem `x_cp_*`; Redis (global + master/replica/sentinel), Traefik, Tempo (`storageClass: null` → `local-path`), Vault data/audit, exemplos OTel statefulset; HOWTO §1, §8, nova §10; `kubectl`: `local-path` default no cluster, PVCs Loki/Thanos ainda `gp3-default` (pendentes) até migração de STS/VCT; este registo.

### Prompt 34

(Continuação após resumo) Corrigir deploy OTel (schema / EKS vs K3s), timeout Jaeger, alinhar documentação.

**Resultado:** `affinity` + `tolerations` no `values-development.yaml` / `values-production.yaml` do OpenTelemetry; removido `config/helm-overrides/k3s/opentelemetry-collector.yaml`; `deploy-workload.sh`: `--timeout 20m` para `jaeger`; HOWTO §3, §7, §8; este registo.

### Prompt 35

Logs CI EKS: OTel OK; Jaeger `jaeger-cassandra-schema` `DeadlineExceeded`; Loki/Thanos `StatefulSet ... Forbidden`.

**Resultado:** `schema.activeDeadlineSeconds` 300 → 1800 em `development/workload-obs/jaeger/values-development.yaml` e `values.yaml`; `deploy-workload.sh`: timeout Jaeger 20m → 35m; HOWTO §3, §9 (DeadlineExceeded vs Helm); Loki/Thanos: apenas documentado em §10 (imutabilidade VCT); este registo.

### Prompt 36

Definir `nodeSelector` do Jaeger para o nó `fedora` (K3s dev).

**Resultado:** `development/workload-obs/jaeger/values-development.yaml`: `nodeSelector.kubernetes.io/hostname: fedora` em `schema`, `collector` e `query`; `config/helm-overrides/k3s/jaeger.yaml`: removida `affinity` duplicada (mantidas `tolerations`); HOWTO §9; este registo.

### Prompt 37

Correr `tools/bump-deploy-ack.sh` para todas as pastas, commit e push.

**Resultado:** `bash tools/bump-deploy-ack.sh` → `2026-04-04T00:36:16Z` em 39 `deploy.ack`; commit `49b710b` + push `main`; este registo.

### Prompt 38

Correr `tools/bump-deploy-ack.ps1`.

**Resultado:** Timestamp `2026-04-04T02:09:18Z` em 39 `deploy.ack`; commit `fb38839` + push `main`; este registo.

## 2026-04-04

### Prompt 1

Executar o plano de observabilidade única por cluster (sem alterar Vault); apagar primeiro todos os namespaces de workload via `kubectl`.

**Resultado:** Charts em `observability/workload-obs/`; `cluster-map` com `observability.namespace`; `load-cluster-env.sh` / `deploy-workload.sh` / `k8s-deploy.yml` / Traefik e refs OTEL atualizados; remoção de `nodeSelector` `fedora` em `jaeger/values-production.yaml`; documentação HOWTO/README/README-deploy-ack; `bump-deploy-ack.ps1`; `kubectl delete namespace` dos workloads + `platform-workload-obs` (com `--wait`); este registo.

### Prompt 2

Correr `tools/bump-deploy-ack.ps1`, commit e push.

**Resultado:** Timestamp `2026-04-04T03:45:35Z` nos `deploy.ack` afetados; commit + push `main`; este registo.
