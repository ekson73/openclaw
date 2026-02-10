#!/bin/bash
set -euo pipefail

#═══════════════════════════════════════════════════════════════════════════════
# upgrade.sh — Atualiza OpenClaw do fork local
#═══════════════════════════════════════════════════════════════════════════════
#
# Uso:
#   ./scripts/upgrade.sh              # Atualiza do branch atual
#   ./scripts/upgrade.sh --staging    # Atualiza do staging
#   ./scripts/upgrade.sh --develop    # Atualiza do develop
#   ./scripts/upgrade.sh --dry-run    # Apenas simula
#
# O que faz:
#   1. git fetch + pull no fork local
#   2. pnpm install + build
#   3. Reinstala via npm link
#
#═══════════════════════════════════════════════════════════════════════════════

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Auto-detectar diretório do fork
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORK_DIR="${OPENCLAW_FORK_DIR:-$(dirname "$SCRIPT_DIR")}"
WORKTREES_DIR="${FORK_DIR}/.worktrees"

# Flags
DRY_RUN=0
TARGET_BRANCH=""
USE_WORKTREE=0
RESTART_GATEWAY=0

# Parse args
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --staging)
            TARGET_BRANCH="staging"
            USE_WORKTREE=1
            shift
            ;;
        --develop)
            TARGET_BRANCH="develop"
            USE_WORKTREE=1
            shift
            ;;
        --restart)
            RESTART_GATEWAY=1
            shift
            ;;
        --help|-h)
            echo "Uso: $0 [opções]"
            echo ""
            echo "Opções:"
            echo "  --dry-run    Apenas simula, não executa"
            echo "  --staging    Usa branch staging (pré-PROD)"
            echo "  --develop    Usa branch develop (bleeding edge)"
            echo "  --restart    Reinicia gateway após upgrade"
            echo ""
            echo "Default: branch atual (main = PROD)"
            echo ""
            echo "Variáveis de ambiente:"
            echo "  OPENCLAW_FORK_DIR  Diretório do fork (default: auto-detectado)"
            exit 0
            ;;
        *)
            echo -e "${RED}Opção desconhecida: $1${NC}"
            exit 1
            ;;
    esac
done

echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║           🔄 OpenClaw Fork Upgrade                            ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Função para executar ou simular
run() {
    if [[ $DRY_RUN -eq 1 ]]; then
        echo -e "${YELLOW}[DRY-RUN] $*${NC}"
    else
        echo -e "${CYAN}$ $*${NC}"
        "$@"  # Safer than eval - prevents command injection
    fi
}

# Determinar diretório de trabalho
if [[ $USE_WORKTREE -eq 1 && -d "$WORKTREES_DIR/$TARGET_BRANCH" ]]; then
    WORK_DIR="$WORKTREES_DIR/$TARGET_BRANCH"
else
    WORK_DIR="$FORK_DIR"
fi

# Verificar se diretório existe
if [[ ! -d "$WORK_DIR" ]]; then
    echo -e "${RED}❌ Diretório não encontrado: $WORK_DIR${NC}"
    exit 1
fi

# Validar que é um checkout do OpenClaw (package.json + .git obrigatórios)
if [[ ! -f "$WORK_DIR/package.json" ]] || [[ ! -d "$WORK_DIR/.git" ]]; then
    echo -e "${RED}❌ Diretório não parece ser um checkout do OpenClaw${NC}"
    echo -e "${YELLOW}Esperado: package.json e .git em $WORK_DIR${NC}"
    echo -e "${YELLOW}Verifique se OPENCLAW_FORK_DIR está correto.${NC}"
    exit 1
fi

# Validar Node.js 22.12.0+
if ! command -v node &> /dev/null; then
    echo -e "${RED}❌ Node.js não encontrado${NC}"
    exit 1
fi
NODE_VERSION=$(node --version)
NODE_MAJOR=$(echo "$NODE_VERSION" | sed 's/v//' | cut -d. -f1)
NODE_MINOR=$(echo "$NODE_VERSION" | sed 's/v//' | cut -d. -f2)
if [[ "$NODE_MAJOR" -lt 22 ]] || [[ "$NODE_MAJOR" -eq 22 && "$NODE_MINOR" -lt 12 ]]; then
    echo -e "${RED}❌ Node.js 22.12.0+ é necessário (encontrado: $NODE_VERSION)${NC}"
    exit 1
fi

cd "$WORK_DIR"

# Determinar branch atual se não especificado
if [[ -z "$TARGET_BRANCH" ]]; then
    TARGET_BRANCH=$(git branch --show-current 2>/dev/null || echo "main")
fi

# Mostrar versão atual
CURRENT_VERSION=$(grep '"version"' package.json 2>/dev/null | sed 's/.*: "\(.*\)".*/\1/' | head -1 || echo "unknown")
CURRENT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

echo -e "${BLUE}📍 Estado atual:${NC}"
echo -e "   Diretório: $WORK_DIR"
echo -e "   Branch:    $TARGET_BRANCH"
echo -e "   Versão:    $CURRENT_VERSION"
echo -e "   Commit:    $CURRENT_COMMIT"
echo ""

# Verificar se há atualizações
echo -e "${BLUE}→ Verificando atualizações...${NC}"
run "git fetch origin"

LOCAL_COMMIT=$(git rev-parse HEAD)
REMOTE_COMMIT=$(git rev-parse "origin/$TARGET_BRANCH" 2>/dev/null || echo "")

if [[ -z "$REMOTE_COMMIT" ]]; then
    echo -e "${RED}❌ Branch origin/$TARGET_BRANCH não encontrada${NC}"
    exit 1
fi

if [[ "$LOCAL_COMMIT" == "$REMOTE_COMMIT" ]]; then
    echo -e "${GREEN}✅ Já está atualizado!${NC}"
    echo ""
    echo -e "${BLUE}→ Reinstalando para garantir integridade...${NC}"
else
    if [[ $DRY_RUN -eq 0 ]]; then
        COMMITS_BEHIND=$(git rev-list --count HEAD..origin/$TARGET_BRANCH)
        echo -e "${YELLOW}⚡ $COMMITS_BEHIND commits novos disponíveis${NC}"
        echo ""
        
        # Mostrar commits novos
        echo -e "${BLUE}📋 Novos commits:${NC}"
        git log --oneline HEAD..origin/$TARGET_BRANCH | head -10
        echo ""
    fi
    
    # Pull
    echo -e "${BLUE}→ Atualizando código...${NC}"
    run "git pull origin $TARGET_BRANCH"
fi

# Mostrar nova versão
echo ""
NEW_VERSION=$(grep '"version"' package.json 2>/dev/null | sed 's/.*: "\(.*\)".*/\1/' | head -1 || echo "unknown")
NEW_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

echo -e "${GREEN}📍 Estado após update:${NC}"
echo -e "   Versão: $NEW_VERSION"
echo -e "   Commit: $NEW_COMMIT"
echo ""

# Reinstalar dependências
echo -e "${BLUE}→ Instalando dependências...${NC}"
run "pnpm install --frozen-lockfile"
echo ""

# Build
echo -e "${BLUE}→ Buildando...${NC}"
run "pnpm build"
echo ""

# Reinstalar
echo -e "${BLUE}→ Reinstalando via npm link...${NC}"
run "npm link"
echo ""

# Gerar checksum
if [[ -f "${SCRIPT_DIR}/build.sh" ]]; then
    echo -e "${BLUE}→ Gerando checksum...${NC}"
    run "${SCRIPT_DIR}/build.sh checksum"
    echo ""
fi

# Verificar instalação
echo -e "${BLUE}→ Verificando instalação...${NC}"

if [[ $DRY_RUN -eq 0 ]]; then
    if command -v openclaw &> /dev/null; then
        INSTALLED_VERSION=$(openclaw --version 2>/dev/null | head -1)
        echo -e "${GREEN}✅ OpenClaw atualizado: $INSTALLED_VERSION${NC}"
    else
        echo -e "${YELLOW}⚠️  openclaw não encontrado no PATH atual${NC}"
    fi
fi

# Reiniciar gateway se solicitado
if [[ $RESTART_GATEWAY -eq 1 ]]; then
    echo ""
    echo -e "${BLUE}→ Reiniciando gateway...${NC}"
    run "openclaw gateway restart"
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              ✅ Upgrade concluído com sucesso!                 ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"

if [[ $RESTART_GATEWAY -eq 0 ]]; then
    echo ""
    echo -e "${YELLOW}💡 Dica: Para aplicar as mudanças no gateway:${NC}"
    echo -e "   openclaw gateway restart"
    echo -e "   # ou use: $0 --restart"
fi
