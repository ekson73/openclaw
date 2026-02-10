# LINEAGE.md

## Origem
- **Criado por:** Eko
- **Parent session:** agent:main:discord
- **Data:** 2026-02-09T13:07:19Z
- **Branch base:** develop

## Objetivo

Adicionar scripts genéricos para operações do fork:
- **gateway-start.sh** — Iniciar gateway com variáveis de ambiente
- **guardian.sh** — Watchdog para monitorar e reiniciar gateway
- **health-check.sh** — Health checks do sistema
- **rollback.sh** — Rollback seguro para versão anterior
- **build.sh** — Build do fork (atualizado)
- **install.sh** — Instalação via npm link (atualizado)
- **upgrade.sh** — Atualização com pull + rebuild (atualizado)

Características:
- Zero hardcodes pessoais (sem "eko", sem "~/Projects/")
- Auto-detecção de paths via `OPENCLAW_FORK_DIR`
- Variáveis de ambiente configuráveis
- Compatíveis com launchd (PATH explícito)
- Funcionam standalone

## Arquivos Principais
- `scripts/gateway-start.sh` (novo)
- `scripts/guardian.sh` (novo)
- `scripts/health-check.sh` (novo)
- `scripts/rollback.sh` (novo)
- `scripts/build.sh` (atualizado)
- `scripts/install.sh` (atualizado)
- `scripts/upgrade.sh` (atualizado)
- `docs/GITHUB-APP-SETUP.md` (atualizado)

## Dependências
- Depende de: PR #6 (setup-worktree.sh) ✅ MERGED
- Bloqueado por: nada

## Status
- [x] Implementação
- [x] Testes (dry-run + health-check full)
- [x] Documentação
- [ ] PR criado
- [ ] Review aprovado

---
*Gerado automaticamente por setup-worktree.sh*
*Atualizado por Eko em 2026-02-09*
