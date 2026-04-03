# Examples — `k8s_stack`

Exemplos copy-paste ou cenários típicos.

## Exemplo 1 — Um único cluster K3s para dev, staging e prod

Em [`config/cluster-map.yaml`](../config/cluster-map.yaml), define um cluster partilhado e usa o mesmo `clusterRef` nos três ambientes:

```yaml
clusters:
  k3s_shared:
    provider: k3s
    k3s:
      description: K3s on-prem partilhado

environments:
  development:
    repoPath: development
    clusterRef: k3s_shared
    # ...
  staging:
    repoPath: staging
    clusterRef: k3s_shared
    # ...
  production:
    repoPath: production
    clusterRef: k3s_shared
    # ...
```

No GitHub, podes usar o **mesmo** secret **`KUBECONFIG`** nos três Environments **se** for o mesmo API server; a separação fica nos namespaces `development-workload-*`, etc.

## Exemplo 2 — Gerar o valor do secret `KUBECONFIG` (Linux/macOS)

```bash
# A partir de um ficheiro kubeconfig
base64 -w0 ~/.kube/config > kube.b64.txt
# Colar o conteúdo de kube.b64.txt no secret KUBECONFIG do GitHub Environment
```

No Windows (PowerShell):

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("$env:USERPROFILE\.kube\config"))
```

## Exemplo 3 — Preencher `topology-standalone.yaml` (override global)

Só faz sentido se **vários** charts no mesmo workload aceitarem a mesma chave. Exemplo ilustrativo (ajusta aos charts reais):

```yaml
# Cuidado: chaves inválidas para um chart podem falhar o helm template
global:
  singleReplica: true
```

Na prática costuma ser mais seguro deixar `{}` e editar cada `values-development.yaml` (como no Redis).

## Exemplo 4 — Ordem de merge Helm (mental model)

Para a app `redis` em `development/workload-common/redis/`:

```text
values-development.yaml          ← principal
topology-standalone.yaml         ← merge se deploymentMode=standalone em development
```

Comando equivalente:

```bash
helm upgrade --install redis . \
  -n development-workload-common \
  -f values-development.yaml \
  -f ../../../../config/helm-overrides/topology-standalone.yaml
```

(O CI faz isto via `deploy-workload.sh` com caminhos corretos.)

## Exemplo 5 — Restart manual de um Deployment

1. Actions → **Deployment restart** → Run workflow.
2. Escolher Environment (`development`, `staging`, `production`).
3. **deployment_name:** nome do objeto Deployment (ex.: `redis-master`).
4. **namespace:** ex.: `development-workload-common`.

O workflow usa o mesmo `cluster-map` e secrets do Environment escolhido.

## Exemplo 6 — Produção em EKS e dev em K3s (misto)

No `cluster-map.yaml`:

- `development.clusterRef` → entrada com `provider: k3s`.
- `production.clusterRef` → entrada com `provider: eks` e `eks.clusterName`.

No GitHub: no Environment `development` só `KUBECONFIG`; no `production` secrets AWS. O workflow só corre **Credenciais AWS** quando `KUBE_PROVIDER == eks` após `load-cluster-env.sh`.
