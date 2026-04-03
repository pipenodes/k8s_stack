# k8s_stack

[![Kubernetes deploy](https://img.shields.io/github/actions/workflow/status/pipenodes/k8s_stack/k8s-deploy.yml?branch=main&logo=github&label=Kubernetes%20deploy)](https://github.com/pipenodes/k8s_stack/actions/workflows/k8s-deploy.yml)
[![Deployment restart](https://img.shields.io/github/actions/workflow/status/pipenodes/k8s_stack/deployment-restart.yml?branch=main&logo=github&label=Deployment%20restart)](https://github.com/pipenodes/k8s_stack/actions/workflows/deployment-restart.yml)
[![Docs](https://img.shields.io/badge/docs-HOWTO%20%26%20Examples-0366d6?logo=gitbook)](docs/)

Monorepo de manifests Kubernetes com deploy na branch `main` via **GitHub Actions**. **Provedor por defeito no mapa:** **K3s on‑premises** para development, staging e production (ajustável). Namespaces: `<repoPath>-workload-*` (ex.: `development-workload-common`).

> **Nota:** Se o repositório GitHub tiver outro `owner/name`, atualiza os URLs nos shields acima (substituir `pipenodes/k8s_stack`).

## Índice

| Secção | Conteúdo |
|--------|----------|
| [Documentação (`docs/`)](#documentação-docs) | HOWTO, exemplos, índice dos ficheiros em `docs/`. |
| [Configuração versionada](#configuração-versionada) | `cluster-map`, topologia, overrides Helm, GitHub Environments. |
| [Um único K3s](#um-único-k3s-para-todos-os-ambientes) | Partilhar cluster entre ambientes. |
| [Topologia e custo](#topologia-e-custo) | `standalone` / `clustered`, `nodeAffinity`. |
| [Clusters e namespaces](#clusters-e-namespaces) | K3s, kubeconfig, AWS condicional. |
| [GitHub Actions](#github-actions) | Workflows e scripts. |
| [Secrets](#secrets) | Por Environment. |
| [Ferramenta de prefixos](#ferramenta-local-de-prefixos) | `prefix_namespaces.py`. |
| [Estrutura por ambiente](#estrutura-por-ambiente) | Pastas `workload-*` e namespaces. |
| [Convenção Helm](#convenção-helm) | Nomes dos ficheiros `values-*.yaml`. |
| [Ordem dos deploys](#ordem-dos-deploys-no-workflow) | Dev e prod no CI. |
| [Migração de namespaces](#migração-a-partir-de-namespaces-antigos) | Prefixos `<env>-workload-*`. |

## Documentação (`docs/`)

Documentação alargada vive em **[`docs/`](docs/)**. Índice:

| Documento | Descrição |
|-----------|-----------|
| [`docs/README.md`](docs/README.md) | Índice da pasta `docs/`. |
| [`docs/HOWTO.md`](docs/HOWTO.md) | Fluxo de deploy, `config/`, scripts, merge dos ficheiros `topology-standalone` / `topology-clustered`, workflows. |
| [`docs/examples.md`](docs/examples.md) | Exemplos: K3s partilhado, secret `KUBECONFIG`, overrides Helm, restart manual, misto EKS/K3s. |

## Configuração versionada

| Ficheiro | Função |
|----------|--------|
| [`config/cluster-map.yaml`](config/cluster-map.yaml) | Liga cada ambiente a um `clusterRef` (`k3s_development`, `k3s_staging`, `k3s_production` ou o mesmo ID para um único K3s partilhado). |
| [`config/workload-topology.yaml`](config/workload-topology.yaml) | **standalone** vs **clustered** e **nodeAffinity** enabled/disabled por ambiente (custo menor fora de produção). |
| [`config/helm-overrides/topology-standalone.yaml`](config/helm-overrides/topology-standalone.yaml) / [`topology-clustered.yaml`](config/helm-overrides/topology-clustered.yaml) | Merge opcional após `values-*.yaml` no Helm (editar com chaves dos vossos charts). |
| [`config/github-environments.yaml`](config/github-environments.yaml) | Contrato de secrets por provedor. |

### Um único K3s para todos os ambientes

No [`cluster-map.yaml`](config/cluster-map.yaml), usa o **mesmo** `clusterRef` em `development`, `staging` e `production` (ex.: apontar todos para `k3s_shared` e definir esse cluster em `clusters`). A separação fica só nos namespaces `<env>-workload-*`.

### Topologia e custo

| Ambiente (exemplo no mapa) | `deploymentMode` | `nodeAffinity` | Objetivo |
|----------------------------|------------------|----------------|----------|
| development / staging | `standalone` | `disabled` | Menos réplicas / menos pressão no scheduler; reduz recurso |
| production | `clustered` | `enabled` | HA e colocação em nós (preencher `affinity` nos values ou nos overrides) |

O [`deploy-workload.sh`](.github/scripts/deploy-workload.sh) faz merge de `config/helm-overrides/topology-<mode>.yaml` quando existe e o `yq` está disponível. Afinar **chart a chart** nos `values-*.yaml` ou nos ficheiros de override. Detalhes: [HOWTO — overrides de topologia](docs/HOWTO.md).

## Clusters e namespaces

- **K3s:** configurar o secret **`KUBECONFIG`** com o **conteúdo textual** do ficheiro kubeconfig (a UI do GitHub aceita **multilinha**; não usar base64). O passo **Credenciais AWS** no workflow só corre se `KUBE_PROVIDER == eks` (após carregar o mapa).

## GitHub Actions

| Workflow | Descrição |
|----------|-----------|
| [`.github/workflows/k8s-deploy.yml`](.github/workflows/k8s-deploy.yml) | `deploy-development` / `deploy-production` com `environment` + `load-cluster-env.sh` (provedor + topologia). |
| [`.github/workflows/deployment-restart.yml`](.github/workflows/deployment-restart.yml) | Restart manual; mesmo fluxo de credenciais condicionais. |

Scripts: [`configure-kube.sh`](.github/scripts/configure-kube.sh), [`load-cluster-env.sh`](.github/scripts/load-cluster-env.sh), [`deploy-workload.sh`](.github/scripts/deploy-workload.sh), [`deploy-cronjobs.sh`](.github/scripts/deploy-cronjobs.sh).

**EKS vs K3s:** o [`load-cluster-env.sh`](.github/scripts/load-cluster-env.sh) só exporta `EKS_CLUSTER_NAME` quando o [`cluster-map.yaml`](config/cluster-map.yaml) tem `provider: eks` para o `clusterRef` do ambiente. Com **K3s**, o workflow usa apenas o secret `KUBECONFIG`; não é necessário nome de cluster EKS no CI.

### Secrets

Por **Environment** (ver [`github-environments.yaml`](config/github-environments.yaml)):

- **K3s:** `KUBECONFIG` (obrigatório para o CI falar com o API server; runners precisam de rota à rede on‑prem se for o caso).
- **EKS (se mudarem o mapa para `provider: eks`):** `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION`.

### Ferramenta local de prefixos

[`tools/prefix_namespaces.py`](tools/prefix_namespaces.py) — alinhar referências `workload-*` nos overlays.

## Estrutura por ambiente

Dentro de `development/`, `staging/` (opcional), `production/`:

| Pasta | Namespace de deploy | Conteúdo típico |
|-------|---------------------|-----------------|
| `workload-common/` | `<env>-workload-common` | Vault, Traefik, Redis, JupyterLab, … |
| `workload-vault/` | `<env>-workload-vault` | Vault Secrets Operator |
| `workload-obs/` | `<env>-workload-obs` | Observabilidade |
| `cron-jobs/` | manifests (ex.: `kube-system`) | CronJobs cluster-wide |

## Convenção Helm

- **Development:** `values-development.yaml`
- **Staging:** `values-staging.yaml`
- **Production:** `values-production.yaml`

## Ordem dos deploys no workflow

1. Development (paths sob `development/**`)
2. Production (paths sob `production/**`)

## Migração a partir de namespaces antigos

Se existirem releases nos namespaces antigos (sem prefixo de ambiente), planear migração para `development-workload-*` / `production-workload-*`.
