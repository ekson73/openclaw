#!/bin/bash
set -euo pipefail

#═══════════════════════════════════════════════════════════════════════════════
# install.sh — Instala OpenClaw do fork local
#═══════════════════════════════════════════════════════════════════════════════
#
# Uso:
#   ./scripts/install.sh              # Instalação padrão
#   ./scripts/install.sh --dry-run    # Apenas simula
#   ./scripts/install.sh --link       # Usa npm link (dev mode)
#   ./scripts/install.sh --global     # Instala globalmente
#
# Pré-requisitos:
#   - Node.js 22+ instalado
#   - pnpm instalado
#
#═══════════════════════════════════════════════════════════════════════════════

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Auto-detectar diretório do fork
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORK_DIR="${OPENCLAW_FORK_DIR:-$(dirname "$SCRIPT_DIR")}"

# Flags
DRY_RUN=0
USE_LINK=0
INSTALL_GLOBAL=0

# Parse args
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --link)
            USE_LINK=1
            shift
            ;;
        --global)
            INSTALL_GLOBAL=1
            shift
            ;;
        --help|-h)
            echo "Uso: $0 [opções]"
            echo ""
            echo "Opções:"
            echo "  --dry-run    Apenas simula, não executa"
            echo "  --link       Usa npm link (modo desenvolvimento)"
            echo "  --global     Instala globalmente via npm"
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

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           🦞 OpenClaw Fork Install                            ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Função para executar ou simular
run() {
    if [[ $DRY_RUN -eq 1 ]]; then
        echo -e "${YELLOW}[DRY-RUN] $*${NC}"
    else
        echo -e "${CYAN}$ $*${NC}"
        eval "$@"
    fi
}

# Verificar se fork existe
if [[ ! -d "$FORK_DIR" ]]; then
    echo -e "${RED}❌ Fork não encontrado em $FORK_DIR${NC}"
    echo -e "${YELLOW}Clone o fork primeiro:${NC}"
    echo -e "  git clone <your-fork-url> $FORK_DIR"
    echo -e "${YELLOW}Ou defina OPENCLAW_FORK_DIR para apontar para seu fork existente.${NC}"
    exit 1
fi

cd "$FORK_DIR"

# Mostrar info do fork
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
CURRENT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
VERSION=$(grep '"version"' package.json 2>/dev/null | sed 's/.*: "\(.*\)".*/\1/' | head -1 || echo "unknown")

echo -e "${GREEN}✓ Fork: $FORK_DIR${NC}"
echo -e "${GREEN}✓ Branch: $CURRENT_BRANCH${NC}"
echo -e "${GREEN}✓ Commit: $CURRENT_COMMIT${NC}"
echo -e "${GREEN}✓ Versão: $VERSION${NC}"
echo ""

# Verificar dependências
echo -e "${BLUE}→ Verificando dependências...${NC}"

if ! command -v node &> /dev/null; then
    echo -e "${RED}❌ Node.js não encontrado${NC}"
    exit 1
fi
NODE_VERSION=$(node --version)
echo -e "${GREEN}✓ Node.js: $NODE_VERSION${NC}"

if ! command -v pnpm &> /dev/null; then
    echo -e "${YELLOW}⚠️  pnpm não encontrado, instalando...${NC}"
    run "npm install -g pnpm"
fi
PNPM_VERSION=$(pnpm --version 2>/dev/null || echo "unknown")
echo -e "${GREEN}✓ pnpm: $PNPM_VERSION${NC}"
echo ""

# Instalar dependências
echo -e "${BLUE}→ Instalando dependências do fork...${NC}"
run "pnpm install --frozen-lockfile"
echo ""

# Build
echo -e "${BLUE}→ Buildando...${NC}"
run "pnpm build"
echo ""

# Instalar
if [[ $USE_LINK -eq 1 ]]; then
    echo -e "${BLUE}→ Criando link simbólico (modo dev)...${NC}"
    run "npm link"
elif [[ $INSTALL_GLOBAL -eq 1 ]]; then
    echo -e "${BLUE}→ Instalando globalmente...${NC}"
    run "npm install -g ."
else
    # Default: npm link (mais seguro para dev)
    echo -e "${BLUE}→ Criando link simbólico...${NC}"
    run "npm link"
fi
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
    # Recarregar PATH
    export PATH="$HOME/.volta/bin:$HOME/.local/bin:/usr/local/bin:$PATH"
    
    if command -v openclaw &> /dev/null; then
        INSTALLED_VERSION=$(openclaw --version 2>/dev/null | head -1)
        INSTALLED_PATH=$(command -v openclaw)
        echo -e "${GREEN}✅ OpenClaw instalado: $INSTALLED_VERSION${NC}"
        echo -e "${GREEN}✅ Binário: $INSTALLED_PATH${NC}"
    else
        echo -e "${YELLOW}⚠️  openclaw não encontrado no PATH atual${NC}"
        echo -e "${YELLOW}   Tente abrir um novo terminal ou executar:${NC}"
        echo -e "${CYAN}   source ~/.bashrc  # ou ~/.zshrc${NC}"
    fi
else
    echo -e "${YELLOW}[DRY-RUN] Verificação pulada${NC}"
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              ✅ Instalação concluída!                          ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Próximos passos:"
echo -e "  ${CYAN}openclaw gateway start${NC}    # Iniciar gateway"
echo -e "  ${CYAN}openclaw status${NC}           # Ver status"
