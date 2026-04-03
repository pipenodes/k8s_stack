# HOWTO — `k8s_stack`

Guia operacional para navegar no monorepo, configurar clusters e perceber o que o CI faz.

## 1. Ideia geral

- **Pastas por ambiente lógico:** `development/`, `staging/` (opcional), `production/` — cada uma com `workload-common`, `workload-vault`, `workload-obs`, `cron-jobs`.
- **Namespace no cluster:** `<repoPath>-<workload>` — exemplo: pasta `development/workload-common` → namespace **`development-workload-common`**.
- **Deploy:** GitHub Actions na branch `main`, com filtros de paths; cada job usa um **GitHub Environment** (`development`, `staging`, `production`) para secrets.
- **CockroachDB** (`workload-common/cockroachdb-parent`): chart oficial [cockroachdb-parent](https://github.com/cockroachdb/helm-charts/tree/master/cockroachdb-parent) (CockroachDB Operator + CRDB). O CI usa `helm upgrade` como nas outras apps; primeiro deploy pode demorar (CRDs, operator, certificados). Ajusta em `values-*-*.yaml` os campos `operator.cloudRegion` e `cockroachdb.cockroachdb.crdbCluster.regions[].code` para coincidirem com `topology.kubernetes.io/region` nos nós, se existir.

## 2. Ficheiros em `config/`

### `cluster-map.yaml`

- Define **`clusters`** (ex.: K3s on-prem) com `provider: k3s` e identificadores (`k3s_development`, …).
- Define **`environments`**: cada um tem `clusterRef`, `repoPath`, `githubEnvironment`, `valuesFileHelm`.

**Um único K3s para todos:** usa o mesmo `clusterRef` em `development`, `staging` e `production`. A separação é só pelos namespaces `development-workload-*`, `staging-workload-*`, `production-workload-*`.

### `github-environments.yaml`

Contrato de **nomes de secrets** esperados por provedor (EKS, K3s, …). Os **valores** configuram-se na UI do GitHub → Settings → Environments.

Para **K3s**, o essencial é o secret **`KUBECONFIG`** com o **conteúdo YAML** do kubeconfig em **texto claro** (multilinha na UI do GitHub), por Environment.

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
| `configure-kube.sh` | `eks` → `aws eks update-kubeconfig` (2.º arg = nome do cluster); `k3s` → lê env `KUBECONFIG` (texto do kubeconfig), escreve ficheiro e exporta `KUBECONFIG` para o caminho. |
| `deploy-workload.sh` | Helm/kubectl por pasta de app; merge dos overrides de topologia como acima. |
| `deploy-cronjobs.sh` | `kubectl apply` em `cron-jobs/`. |

## 4. Workflows GitHub Actions

- **`k8s-deploy.yml`:** jobs `deploy-development` e `deploy-production`; **credenciais AWS** só quando `KUBE_PROVIDER == eks` (após carregar o mapa).
- **`deployment-restart.yml`:** restart manual de um Deployment; mesmo critério para AWS.

O workflow chama `configure-kube.sh` com **dois argumentos** apenas quando `KUBE_PROVIDER=eks` (nome do cluster); com **K3s** passa só o provedor — `EKS_CLUSTER_NAME` não é definido pelo `load-cluster-env.sh` quando o mapa é K3s.

## 5. Onde afinar custo / scheduling

1. **`workload-topology.yaml`** — modo por ambiente.
2. **`helm-overrides/topology-*.yaml`** — overrides transversais (quando fizer sentido).
3. **`values-development.yaml` / `values-staging.yaml` / `values-production.yaml`** por chart — controlo fino (ex.: Redis: standalone em dev, sem anti-affinity em prod).

Ver também [examples.md](examples.md).
