#!/bin/bash
#===============================================================================
# OPENCLAW ROLLBACK/RECOVERY
# Recovery do gateway com opção de rollback para commit anterior
#
# Uso: ./scripts/rollback.sh [--auto|test|to <commit>|help]
#===============================================================================

# PATH explícito para funcionar via launchd
export PATH="${HOME}/.volta/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

set -euo pipefail

# Auto-detectar diretórios
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORK_DIR="${OPENCLAW_FORK_DIR:-$(dirname "$SCRIPT_DIR")}"

# Configurações
LOG_DIR="${HOME}/.openclaw/logs"
LOG_FILE="${LOG_DIR}/rollback.log"
BACKUP_DIR="${HOME}/.openclaw/backup"

mkdir -p "$LOG_DIR" "$BACKUP_DIR"

# Auto-detectar binário OpenClaw
if command -v openclaw &>/dev/null; then
    OPENCLAW_BIN="openclaw"
elif [ -x "${HOME}/.volta/bin/openclaw" ]; then
    OPENCLAW_BIN="${HOME}/.volta/bin/openclaw"
else
    OPENCLAW_BIN="node ${FORK_DIR}/dist/openclaw.mjs"
fi

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Recovery simples: Reinicia o gateway
# Para instalação via Volta/npm, não há "rollback de versão" simples
do_recovery() {
    local mode="${1:-manual}"
    
    log "🔄 Iniciando recovery (modo: $mode)"
    
    # Parar gateway se estiver rodando
    log "⏹️ Parando gateway..."
    $OPENCLAW_BIN gateway stop 2>/dev/null || true
    sleep 2
    
    # Reiniciar gateway
    log "▶️ Iniciando gateway..."
    $OPENCLAW_BIN gateway start 2>/dev/null || true
    
    # Aguardar startup
    log "⏳ Aguardando startup (10s)..."
    sleep 10
    
    # Verificar saúde
    if "${SCRIPT_DIR}/health-check.sh" full 2>/dev/null; then
        log "✅ Recovery concluído com sucesso"
        return 0
    else
        log "❌ Recovery falhou no health check"
        return 1
    fi
}

# Rollback para commit específico (para self-build)
do_rollback_commit() {
    local target="${1:-HEAD~1}"
    
    if [ ! -d "$FORK_DIR/.git" ]; then
        log "❌ Fork não encontrado em $FORK_DIR"
        return 1
    fi
    
    log "🔄 Iniciando rollback para: $target"
    
    cd "$FORK_DIR"
    
    # Salvar commit atual como backup
    local current_commit
    current_commit=$(git rev-parse HEAD)
    echo "$current_commit" > "${BACKUP_DIR}/last-working-commit"
    log "📝 Commit atual salvo: $current_commit"
    
    # Fazer checkout
    log "📥 Checkout para $target..."
    git checkout "$target" --force
    
    # Rebuild
    log "🔨 Rebuilding..."
    pnpm install --frozen-lockfile
    pnpm build
    
    # Gerar novo checksum
    "${SCRIPT_DIR}/build.sh" checksum
    
    # Reiniciar gateway
    log "🔄 Reiniciando gateway..."
    node "${FORK_DIR}/dist/openclaw.mjs" gateway restart || true
    
    # Aguardar startup
    sleep 10
    
    # Verificar saúde
    if "${SCRIPT_DIR}/health-check.sh" full 2>/dev/null; then
        log "✅ Rollback concluído com sucesso"
        return 0
    else
        log "❌ Rollback falhou no health check"
        return 1
    fi
}

# Teste de recovery (dry-run)
test_recovery() {
    log "🧪 Iniciando TESTE de recovery (dry-run)..."
    
    # 1. Verificar binário
    if ! $OPENCLAW_BIN --version >/dev/null 2>&1; then
        log "❌ Binário openclaw não encontrado"
        return 1
    fi
    local version
    version=$($OPENCLAW_BIN --version 2>/dev/null || echo "unknown")
    log "✅ Binário encontrado: $version"
    
    # 2. Verificar se gateway está rodando
    if "${SCRIPT_DIR}/health-check.sh" process 2>/dev/null; then
        log "✅ Gateway está rodando"
    else
        log "⚠️ Gateway não está rodando (recovery iniciaria)"
    fi
    
    # 3. Verificar se consegue obter status
    if $OPENCLAW_BIN gateway status >/dev/null 2>&1; then
        log "✅ Gateway status OK"
    else
        log "⚠️ Gateway status falhou"
    fi
    
    # 4. Verificar fork (se existir)
    if [ -d "$FORK_DIR/.git" ]; then
        cd "$FORK_DIR"
        local current_commit
        current_commit=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
        log "✅ Fork encontrado: $FORK_DIR (commit: $current_commit)"
        
        local previous_commit
        previous_commit=$(git rev-parse --short HEAD~1 2>/dev/null || echo "")
        if [ -n "$previous_commit" ]; then
            log "✅ Commit anterior disponível: $previous_commit"
        else
            log "⚠️ Sem commit anterior para rollback"
        fi
    else
        log "ℹ️ Fork não encontrado (usando instalação global)"
    fi
    
    log "✅ TESTE DE RECOVERY PASSOU"
    return 0
}

# Mostrar ajuda
show_help() {
    echo "OpenClaw Rollback/Recovery"
    echo ""
    echo "Uso: $0 [comando]"
    echo ""
    echo "Comandos:"
    echo "  --auto         Recovery automático (usado pelo guardian)"
    echo "  test           Testar se recovery está funcional (dry-run)"
    echo "  to <commit>    Rollback para commit específico (self-build)"
    echo "  help           Mostrar esta ajuda"
    echo ""
    echo "Variáveis de ambiente:"
    echo "  OPENCLAW_FORK_DIR  Diretório do fork (para rollback de commit)"
}

# Comandos
case "${1:-help}" in
    --auto)
        do_recovery "--auto"
        ;;
    test)
        test_recovery
        ;;
    to)
        shift
        do_rollback_commit "${1:-HEAD~1}"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "Comando desconhecido: $1"
        show_help
        exit 1
        ;;
esac
