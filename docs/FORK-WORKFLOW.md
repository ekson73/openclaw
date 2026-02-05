# OpenClaw Fork Workflow

> Documentação da estrutura de branches e worktrees para manutenção do fork ekson73/openclaw

## Visão Geral

Mantemos nosso próprio fork do OpenClaw para:

- Aplicar fixes sem esperar aprovação do upstream
- Customizar funcionalidades específicas
- Ter controle total sobre o que roda em produção

## Estrutura de Branches

```
upstream/main ──sync──► develop ──merge──► stable
                            ▲
                            │
                      feature/*
                      bugfix/*
                      hotfix/*
```

### Branches Principais

| Branch    | Propósito                             | Proteção                  | Worktree               |
| --------- | ------------------------------------- | ------------------------- | ---------------------- |
| `stable`  | **Produção** - Gateway roda aqui      | 🔒 Só merge de develop    | `~/Projects/oc-stable` |
| `develop` | **Integração** - Testes antes de prod | 🔒 Só merge de feature/\* | `~/Projects/openclaw`  |

### Branches de Trabalho

| Prefixo     | Uso                                   | Exemplo                   |
| ----------- | ------------------------------------- | ------------------------- |
| `feature/*` | Novas funcionalidades                 | `feature/skill-pomodoro`  |
| `bugfix/*`  | Correções normais                     | `bugfix/whatsapp-timeout` |
| `hotfix/*`  | Correções urgentes (direto p/ stable) | `hotfix/critical-crash`   |

## Estrutura de Diretórios (Worktrees)

```
~/Projects/
├── openclaw/           # Repo principal (branch: develop)
│   ├── .git/           # Dados git compartilhados
│   └── ...
├── oc-stable/          # Worktree (branch: stable) ← PRODUÇÃO
│   └── ...             # Gateway roda DAQUI
└── oc-feature/         # Worktree (branch: feature atual)
    └── ...             # Desenvolvimento de features
```

## Setup Inicial

### 1. Criar branches no fork

```bash
cd ~/Projects/openclaw
git checkout main
git fetch upstream
git rebase upstream/main

# Criar branches principais
git checkout -b stable
git checkout -b develop
git push origin stable develop
```

### 2. Criar worktrees

```bash
cd ~/Projects/openclaw
git worktree add ../oc-stable stable
git worktree add ../oc-feature develop
```

### 3. Build de produção

```bash
cd ~/Projects/oc-stable
pnpm install
pnpm build
pnpm ui:build
```

### 4. Instalar gateway do worktree stable

```bash
# Parar gateway atual
openclaw gateway stop

# Desinstalar versão Volta/npm
volta uninstall openclaw

# Instalar do nosso fork (stable)
curl -fsSL https://openclaw.ai/install.sh | bash -s -- \
  --install-method git \
  --git-dir ~/Projects/oc-stable \
  --no-onboard

# Validar
openclaw doctor --fix
openclaw gateway start
openclaw status
```

## Workflows Diários

### Sync com Upstream

```bash
cd ~/Projects/openclaw
git fetch upstream
git checkout develop
git rebase upstream/main
# Resolver conflitos se houver
git push origin develop --force-with-lease
```

### Criar Nova Feature

```bash
cd ~/Projects/openclaw
git checkout develop
git pull origin develop
git checkout -b feature/minha-feature

# Desenvolver no worktree de feature
cd ~/Projects/oc-feature
git checkout feature/minha-feature
# ... fazer alterações ...
pnpm build
# ... testar ...
```

### Promover Feature para Develop

```bash
cd ~/Projects/openclaw
git checkout develop
git merge feature/minha-feature
git push origin develop

# Testar em develop
pnpm build
# ... validar ...
```

### Promover para Produção

```bash
cd ~/Projects/openclaw
git checkout stable
git merge develop
git push origin stable

# Atualizar worktree de produção
cd ~/Projects/oc-stable
git pull origin stable
pnpm install
pnpm build
pnpm ui:build

# Reiniciar gateway
openclaw gateway restart
openclaw status
```

### Hotfix (Emergência)

```bash
# Criar hotfix direto de stable
cd ~/Projects/oc-stable
git checkout -b hotfix/critical-fix

# Fazer correção mínima
# ... fix ...
pnpm build

# Testar rapidamente
# ... validar ...

# Merge direto em stable
git checkout stable
git merge hotfix/critical-fix
git push origin stable

# Reiniciar
openclaw gateway restart

# Backport para develop
cd ~/Projects/openclaw
git checkout develop
git merge hotfix/critical-fix
git push origin develop
```

## Regras de Ouro

### 🤖 Para AI Agents (Eko)

```
╔════════════════════════════════════════════════════════════════╗
║  NUNCA fazer build/test na mesma instância que roda o gateway  ║
║                                                                ║
║  ✅ Gateway rodando    → ~/Projects/oc-stable (stable)         ║
║  ✅ Desenvolvimento    → ~/Projects/openclaw (develop)         ║
║  ✅ Testes de feature  → ~/Projects/oc-feature (feature/*)     ║
║                                                                ║
║  ❌ NUNCA buildar em oc-stable enquanto gateway roda           ║
║  ❌ NUNCA fazer git checkout em oc-stable sem parar gateway    ║
╚════════════════════════════════════════════════════════════════╝
```

### Antes de Qualquer Build em Produção

1. `openclaw gateway stop`
2. Fazer alterações/build
3. `openclaw gateway start`
4. Validar com `openclaw status`

## Comandos Úteis

### Status dos Worktrees

```bash
git worktree list
```

### Ver Diferença entre Branches

```bash
# stable vs develop
git log stable..develop --oneline

# develop vs upstream
git log develop..upstream/main --oneline
```

### Remover Worktree

```bash
git worktree remove ../oc-feature
```

### Limpar Branches Mergeadas

```bash
git branch --merged develop | grep -v "stable\|develop" | xargs git branch -d
```

## Rollback de Emergência

Se algo der errado após promover para stable:

```bash
# Ver commits anteriores
cd ~/Projects/oc-stable
git log --oneline -10

# Reverter para commit específico
git reset --hard <commit-hash>
pnpm build
openclaw gateway restart

# Ou reinstalar via Volta (fallback total)
volta install openclaw@2026.2.2-3
openclaw gateway start
```

## Referências

- [OpenClaw Install Docs](https://docs.openclaw.ai/install)
- [OpenClaw Development Channels](https://docs.openclaw.ai/install/development-channels)
- [Git Worktree Documentation](https://git-scm.com/docs/git-worktree)
- [GitFlow Workflow](https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow)

---

_Criado: 2026-02-04_
_Autor: Eko + Emilson_
