# `deploy.ack` — forçar o CI a ver mudanças

Os workflows usam **paths-filter** (`dorny/paths-filter`): só corre deploy quando há alterações sob `development/**` ou `production/**`. Um ficheiro `deploy.ack` em cada pasta de aplicação (e nas raízes `development/`, `production/`, `cron-jobs/`, `workload-*`) permite **marcar intenção de redeploy** sem editar `values*.yaml`.

## Valor do ficheiro

Por convenção usamos **ISO 8601 em UTC com precisão de segundos**:

`YYYY-MM-DDTHH:MM:SSZ`

Exemplo: `2026-04-03T18:45:00Z`

É legível, ordenável em texto (ordem lexicográfica = ordem temporal) e padrão em APIs/logs. Se precisares de **sub-segundos**, podes passar um valor manual (ex. `2026-04-03T18:45:00.123Z`); os scripts por defeito usam só segundos para compatibilidade com `date` em macOS/BSD.

**Alternativa compacta** (só se preferires número inteiro): epoch Unix em segundos — podes gravar à mão ou `date -u +%s` / `[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()`; os scripts atuais não usam esse formato por defeito.

## Scripts

| Script | Ambiente |
|--------|----------|
| [`bump-deploy-ack.sh`](bump-deploy-ack.sh) | Git Bash / Linux / macOS |
| [`bump-deploy-ack.ps1`](bump-deploy-ack.ps1) | Windows PowerShell |

Ambos percorrem `development/`, `production/` e **`observability/workload-obs/`** e escrevem `deploy.ack` em:

- `<env>/deploy.ack`
- `<env>/cron-jobs/deploy.ack` (se a pasta existir)
- `<env>/workload-{common,vault,obs}/deploy.ack`
- cada subpasta direta desses `workload-*` (ex.: `workload-obs/promtail/deploy.ack`)
- `observability/workload-obs/deploy.ack` e cada subpasta direta do stack de obs (ex.: `observability/workload-obs/loki/deploy.ack`)

**Uso:**

```bash
./tools/bump-deploy-ack.sh                        # agora UTC em ISO 8601
./tools/bump-deploy-ack.sh '2026-12-01T10:00:00Z' # valor fixo
```

```powershell
.\tools\bump-deploy-ack.ps1
.\tools\bump-deploy-ack.ps1 -Value '2026-12-01T10:00:00Z'
```

Depois: `git add` dos `deploy.ack` alterados, commit e push.

## Alternativas (quando não quiseres tocar em `deploy.ack`)

1. **`workflow_dispatch`** no `k8s-deploy.yml` — voltar a correr o workflow manualmente (não depende de paths novos).
2. **Commit vazio** — `git commit --allow-empty -m "chore: rerun deploy"` (só útil se o workflow disparar em *qualquer* push a `main` sem filtro estrito; aqui o filtro é por paths, por isso **commit vazio sozinho não altera paths**).
3. **Mudar só o chart** que precisa de deploy (values, templates) — é a opção mais explícita em review.

Para este repositório, **bump em `deploy.ack`** ou **`workflow_dispatch`** são os caminhos mais alinhados ao paths-filter.
