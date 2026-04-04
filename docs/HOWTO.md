# HOWTO — `k8s_stack`

Guia operacional para navegar no monorepo, configurar clusters e perceber o que o CI faz.

## 1. Ideia geral

- **Pastas por ambiente lógico:** `development/`, `staging/` (opcional), `production/` — cada uma com `workload-common`, `workload-vault`, `workload-obs`, `cron-jobs`.
- **Namespace no cluster:** `<repoPath>-<workload>` — exemplo: pasta `development/workload-common` → namespace **`development-workload-common`**.
- **Deploy:** GitHub Actions na branch `main`, com filtros de paths; cada job usa um **GitHub Environment** (`development`, `staging`, `production`) para secrets.
- **Ordem no CI (mesmo job):** com `KUBE_PROVIDER=k3s`, após kubeconfig válido aplica-se a **StorageClass** [`config/k8s/storageclass-local-path.yaml`](../config/k8s/storageclass-local-path.yaml); depois **`workload-obs`** (Prometheus CRDs), **`workload-vault`**, **`workload-common`**, **`cron-jobs`**. Um push que altere só `workload-common` não corre obs nesse run — o cluster deve já ter observabilidade (ou correr antes um deploy de `workload-obs`). Os `values-*.yaml` de **development** e **production** assumem **`local-path`** onde há PVC; em **EKS** (ou outro provedor) o workflow **não** aplica esse manifest automaticamente — é preciso garantir no cluster o **mesmo nome** `local-path` e um provisionador compatível com `rancher.io/local-path`, ou ajustar o pipeline, senão os PVC ficam pendentes.
- **Dentro de `workload-obs`:** o [`deploy-workload.sh`](../.github/scripts/deploy-workload.sh) instala **`kube-prometheus-stack` antes** dos outros charts (ordem alfabética entre o resto), para existirem CRDs do Prometheus Operator antes de charts que criam `ServiceMonitor` (ex.: Grafana). No mesmo passo, cria-se de forma idempotente o namespace **`<env>-workload-vault`** quando ainda não correu o job `workload-vault` (ex.: OpenTelemetry com `namespaceOverride` para vault).
- **K3s + Traefik:** com `k3s`, o script **não** faz `helm` da pasta `traefik` em `workload-common` (usa o Traefik nativo do K3s).
- **CockroachDB:** antes do `helm` do chart `cockroachdb`, o CI corre [`.github/scripts/apply-crdb-operator-crds.sh`](../.github/scripts/apply-crdb-operator-crds.sh) (CRD remoto; opcional `CRDB_OPERATOR_CRD_REF` para fixar tag/commit). Após alterar `Chart.yaml` de charts com dependências, corre localmente `helm dependency update` e commit dos `charts/*.tgz` / `Chart.lock` se existir.
- **CockroachDB** (`workload-common/cockroachdb/`): chart oficial [cockroachdb-parent](https://github.com/cockroachdb/helm-charts/tree/master/cockroachdb-parent) (CockroachDB Operator + CRDB). O CI usa `helm upgrade` como nas outras apps; primeiro deploy pode demorar (CRDs, operator, certificados). Ajusta em `values-*-*.yaml` os campos `operator.cloudRegion` e `cockroachdb.cockroachdb.crdbCluster.regions[].code` para coincidirem com `topology.kubernetes.io/region` nos nós, se existir.

## 2. Ficheiros em `config/`

### `cluster-map.yaml`

- Define **`clusters`** (ex.: K3s on-prem) com `provider: k3s` e identificadores (`k3s_development`, …).
- Define **`environments`**: cada um tem `clusterRef`, `repoPath`, `githubEnvironment`, `valuesFileHelm`.

**Um único K3s para todos:** usa o mesmo `clusterRef` em `development`, `staging` e `production`. A separação é só pelos namespaces `development-workload-*`, `staging-workload-*`, `production-workload-*`.

### `github-environments.yaml`

Contrato de **nomes de secrets** esperados por provedor (EKS, K3s, …). Os **valores** configuram-se na UI do GitHub → Settings → Environments.

Para **K3s**, o essencial é o secret **`KUBECONFIG`** (nome na UI do GitHub) com o **conteúdo YAML** do kubeconfig em **texto claro** (multilinha), por Environment. Nos workflows o valor é injetado na env **`KUBE_CONFIG`**; a variável **`KUBECONFIG`** no job fica reservada ao caminho do ficheiro após `configure-kube.sh` + `source apply-kubeconfig-env.sh`.

### `workload-topology.yaml`

Por ambiente:

- **`deploymentMode`:** `standalone` (custo menor, menos pressão no scheduler) ou `clustered` (HA / mais réplicas onde fizer sentido).
- **`nodeAffinity`:** `enabled` ou `disabled` — documenta a intenção; afinar **affinity** nos `values-*.yaml` de cada chart ou nos overrides globais.

### Overrides de topologia: `helm-overrides/topology-standalone.yaml` e `topology-clustered.yaml`

**Para que servem**

São um **segundo ficheiro de valores Helm** aplicado **depois** do `values-development.yaml` / `values-production.yaml` de **cada** aplicação no mesmo workload, quando o script [`deploy-workload.sh`](../.github/scripts/deploy-workload.sh) corre no CI.

Fluxo por release:

1. `helm upgrade -f <app>/values-<env>.yaml` — configuração principal do chart.
2. Se existir `config/workload-topology.yaml` e o comando `yq` estiver disponível, lê-se `deploymentMode` **desse** ambiente (`development`, `staging`, `production`).
3. Carrega-se opcionalmente **mais um** `-f config/helm-overrides/topology-<standalone|clustered>.yaml`.

No Helm, **valores mais à direita sobrescrevem os anteriores**, por isso estes ficheiros são o sítio para **política comum** (ex.: `global`, réplicas por defeito, `affinity: {}`) partilhada por **vários** charts, **sem** copiar a mesma coisa para cada `values-*.yaml`.

**Estado atual**

Podem estar com `{}` (vazio) a servir de **placeholder**: o deploy funciona; quando quiseres política transversal, preenches chaves que os vossos charts aceitem na raiz (ou documentas que afinas **só** por app, como no Redis).

**Limitação**

Cada chart tem chaves diferentes (`replicaCount` vs `replica.replicaCount`, etc.). Overrides **globais** só funcionam se as chaves forem compatíveis com **todos** os charts desse passo Helm — por isso muitas equipas misturam: um pouco aqui nos `topology-*.yaml` e o resto **por chart** nos `values-*.yaml`.

## 3. Scripts relevantes

| Script | Função |
|--------|--------|
| `load-cluster-env.sh` | Lê `cluster-map.yaml` (+ topologia) e exporta `KUBE_PROVIDER`, `EKS_CLUSTER_NAME` (se EKS), `TOPOLOGY_MODE`, etc. para o job. |
| `configure-kube.sh` | `eks` → `aws eks update-kubeconfig` (2.º arg = nome do cluster); `k3s` → lê **`KUBE_CONFIG`** (texto do kubeconfig), grava ficheiro; o `source apply-kubeconfig-env.sh` no mesmo `run` exporta **`KUBECONFIG`** = path. |
| `ensure-local-path-storageclass.sh` | Se `KUBE_PROVIDER=k3s`, `kubectl apply` da StorageClass `local-path` em `config/k8s/`. |
| `apply-crdb-operator-crds.sh` | `kubectl apply` do CRD `CrdbCluster` a partir do repositório `cockroachdb-operator` (ref `CRDB_OPERATOR_CRD_REF`, default `master`). |
| `deploy-workload.sh` | Cria namespace do workload; Helm/kubectl por pasta; em `k3s` salta chart `traefik`; antes de cockroachdb aplica CRDs; merge dos overrides de topologia; **`kube-prometheus-stack`** com `--timeout 35m`; **`jaeger`** com `--timeout 35m` (hooks do Job de schema Cassandra; alinhar com `schema.activeDeadlineSeconds` nos values). Em **`workload-obs`:** `kube-prometheus-stack` primeiro; namespace `<env>-workload-vault` criado se necessário. Com **`KUBE_PROVIDER=k3s`** e workload `workload-obs` / `workload-vault` / `workload-common`, faz merge opcional de [`config/helm-overrides/k3s/<nome-do-chart>.yaml`](../config/helm-overrides/k3s/) (scheduling no nó control-plane / servidor). |
| `deploy-cronjobs.sh` | `kubectl apply` em `cron-jobs/`. |
| [`tools/bump-deploy-ack.sh`](../tools/bump-deploy-ack.sh) / [`bump-deploy-ack.ps1`](../tools/bump-deploy-ack.ps1) | Atualizam todos os `deploy.ack` com timestamp **ISO 8601 UTC** (`YYYY-MM-DDTHH:MM:SSZ`) para o paths-filter disparar deploy; ver [README-deploy-ack](../tools/README-deploy-ack.md). |

## 4. Workflows GitHub Actions

- **`k8s-deploy.yml`:** jobs `deploy-development` e `deploy-production`; **StorageClass** (K3s) e workloads na ordem **obs → vault → common → cron**; **credenciais AWS** só quando `KUBE_PROVIDER == eks`.
- **`deployment-restart.yml`:** restart manual de um Deployment; mesmo critério para AWS.

O workflow chama `configure-kube.sh` com **dois argumentos** apenas quando `KUBE_PROVIDER=eks` (nome do cluster); com **K3s** passa só o provedor — `EKS_CLUSTER_NAME` não é definido pelo `load-cluster-env.sh` quando o mapa é K3s.

## 5. Onde afinar custo / scheduling

1. **`workload-topology.yaml`** — modo por ambiente.
2. **`helm-overrides/topology-*.yaml`** — overrides transversais (quando fizer sentido).
3. **`values-development.yaml` / `values-staging.yaml` / `values-production.yaml`** por chart — controlo fino (ex.: Redis: standalone em dev, sem anti-affinity em prod).

Ver também [examples.md](examples.md).

## 6. `kube-prometheus-stack`: nomes cluster-wide e recuperação

Os `ClusterRole` / hooks de admission do chart usam o **`fullnameOverride`** curto (`obs-kps-dev` / `obs-kps-prd`) definido em `values-development.yaml` / `values-production.yaml`, para **evitar colisão** no mesmo cluster físico entre namespaces `development-workload-obs` e `production-workload-obs` e para ficar abaixo do truncamento interno do chart (~26 caracteres) nos nomes de `ServiceAccount`/Jobs do webhook.

O **seletor de `ServiceMonitor`** do Prometheus continua a usar o **nome do release Helm** (`kube-prometheus-stack`, igual ao nome da pasta), não o `fullnameOverride` — por isso as labels `release: kube-prometheus-stack` nos charts dependentes (ex.: Grafana) mantêm-se alinhadas.

Se um deploy falhar a meio e ficarem objetos órfãos do hook de admission, rever com `kubectl get clusterrole,clusterrolebinding | rg admission` (ou equivalente) e remover os associados ao release antigo, ou `helm uninstall <release> -n <namespace>` conforme o estado, antes de voltar a correr o CI.

## 7. RBAC cluster-scoped (dev + prod no mesmo cluster)

Charts como **Loki**, **Promtail** e **OpenTelemetry** criam `ClusterRole` com nomes derivados do release. No **mesmo cluster** com `development-workload-obs` e `production-workload-obs`, os valores usam:

- **Loki:** `fullnameOverride` na raiz (`development-loki` / `production-loki`) — o serviço do gateway passa a `<fullname>-gateway` (ex.: `development-loki-gateway`). Atualizar referências em OTel, Promtail e Traefik (`IngressRoute`).
- **Promtail:** `fullnameOverride` por ambiente (`development-promtail` / `production-promtail`).
- **OpenTelemetry:** `clusterRole.name` e `clusterRole.clusterRoleBinding.name` por ambiente; o **Service** mantém o nome `opentelemetry-collector` (DNS em Loki inalterado). **Affinity** e **tolerations** (control-plane) estão em `values-development.yaml` / `values-production.yaml` do chart — válidas em EKS e K3s e compatíveis com o `values.schema.json` do chart (sem ficheiro K3s extra para este release).

## 8. K3s: scheduling no servidor (control-plane)

A pasta [`config/helm-overrides/k3s/`](../config/helm-overrides/k3s/) contém um YAML **por chart** (nome = pasta do chart, ex.: `loki.yaml`, `kube-prometheus-stack.yaml`). Só entram no `helm upgrade` quando `KUBE_PROVIDER=k3s` e o workload é obs, vault ou common — **não** em EKS e **não** em `cron-jobs`.

Incluem **nodeAffinity** `requiredDuringScheduling` com `Exists` em `node-role.kubernetes.io/control-plane` e **tolerations** para os taints `control-plane` / `master` (sem campo `nodeSelector`). Confirma os labels do nó com `kubectl get nodes --show-labels` e ajusta se o teu K3s usar outra convenção.

**DaemonSets** (ex.: Promtail): o override K3s aplica só **tolerations** (sem affinity a control-plane) para o agente de logs continuar a poder correr em todos os nós.

Os ficheiros em `helm-overrides/k3s/` **não** devem definir chaves raiz “auxiliares” (ex. âncoras YAML) — charts com `values.schema.json` estrito rejeitam propriedades extra no topo do values. O **OpenTelemetry Collector** não usa overlay K3s: scheduling está nos `values-*.yaml` do próprio chart.

## 9. Jaeger (Cassandra): Job de schema e réplicas

- O Job `*-cassandra-schema` é um **hook** Helm (`post-install`/`post-upgrade`) com `helm.sh/hook-delete-policy: before-hook-creation,hook-succeeded`, para o upgrade **apagar e recriar** o Job em vez de tentar patch ao `spec.template` (imutável no Kubernetes).
- Em releases antigos **antes** desta alteração, se o upgrade ainda falhar no Job, apaga manualmente: `kubectl delete job -n <namespace> <release>-cassandra-schema`.
- Em **development**, o subchart Cassandra usa **`cluster_size: 1`** (e `seed_size: 1`) em `values-development.yaml` para evitar gossip entre réplicas quando só há um nó ou pouca rede entre pods.
- Se o hook falhar com **`DeadlineExceeded`** no Job `*-cassandra-schema`, o pod atingiu **`spec.activeDeadlineSeconds`** (ver `schema.activeDeadlineSeconds` em `values-development.yaml` / `values.yaml`). Em EKS o Cassandra pode demorar vários minutos a aceitar CQL; o timeout do Helm para Jaeger no CI deve ser **igual ou superior** a esse deadline.

## 10. StorageClass `local-path` em todos os ambientes e StatefulSets imutáveis

- **Repositório:** `values-development.yaml` e `values-production.yaml` alinham **`local-path`** em PVCs relevantes (Loki, Thanos, Grafana, Redis master/replica/sentinel, Tempo, Vault data/audit, CockroachDB, manifests `jupyterlab`, etc.), para a mesma política em dev e prod.
- **Cluster:** com K3s, o CI aplica [`config/k8s/storageclass-local-path.yaml`](../config/k8s/storageclass-local-path.yaml). Noutro tipo de cluster, se mantiveres os mesmos values, garante manualmente StorageClass `local-path` + provisionador `rancher.io/local-path` (ou equivalente).
- **Erro `StatefulSet ... Forbidden` no `helm upgrade`:** o Kubernetes **não permite** alterar `volumeClaimTemplates` (por exemplo `storageClassName` ou nome do volume claim) num StatefulSet **já existente**. Se os pods foram criados com outra classe e os values passam a pedir `local-path`, o patch falha mesmo com o Git correto. Caminhos típicos: janela de manutenção com **backup**, remoção controlada do StatefulSet (e, se aplicável, PVCs) e novo `helm upgrade`; ou novo nome de release/`fullnameOverride` (novos STS) + migração de dados; ou manter a classe já presente nos PVC até haver plano de migração.
- **Diagnóstico:** `kubectl get storageclass`; `kubectl get pvc -n <namespace>`; `kubectl get sts -n <namespace> -o yaml` e inspecionar `spec.volumeClaimTemplates`.
