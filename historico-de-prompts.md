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
