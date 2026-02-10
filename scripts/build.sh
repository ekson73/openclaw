#!/bin/bash
#===============================================================================
# OPENCLAW FORK BUILD SCRIPT
# Build com checksums SHA256 e validação
#
# Uso: ./scripts/build.sh [build|verify|checksum|run|check-l4]
#===============================================================================

set -euo pipefail

# Auto-detectar diretório do fork
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORK_DIR="${OPENCLAW_FORK_DIR:-$(dirname "$SCRIPT_DIR")}"

# Configurações
DIST_DIR="${FORK_DIR}/dist"
OPENCLAW_BIN="${DIST_DIR}/openclaw.mjs"
CHECKSUM_FILE="${DIST_DIR}/openclaw.sha256"
LOG_DIR="${HOME}/.openclaw/logs"
LOG_FILE="${LOG_DIR}/build.log"

# Criar diretório de logs se não existir
mkdir -p "$LOG_DIR"

# Segurança: Desabilitar Fallback L4 (execução de JS arbitrário)
export OPENCLAW_DISABLE_FALLBACK_L4="true"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$USER]" "$@" | tee -a "$LOG_FILE"
}

# Gerar checksum após build
generate_checksum() {
    if [ -f "$OPENCLAW_BIN" ]; then
        shasum -a 256 "$OPENCLAW_BIN" > "$CHECKSUM_FILE"
        log "✅ Checksum gerado: $(cat "$CHECKSUM_FILE")"
        return 0
    else
        log "❌ Binário não encontrado para gerar checksum"
        return 1
    fi
}

# Verificar checksum antes de executar
verify_checksum() {
    if [ ! -f "$CHECKSUM_FILE" ]; then
        log "⚠️ Arquivo de checksum não encontrado"
        return 1
    fi
    
    if [ ! -f "$OPENCLAW_BIN" ]; then
        log "❌ Binário não encontrado"
        return 1
    fi
    
    if shasum -a 256 -c "$CHECKSUM_FILE" >/dev/null 2>&1; then
        log "✅ Checksum verificado com sucesso"
        return 0
    else
        log "❌ CHECKSUM INVÁLIDO! Binário pode estar corrompido!"
        return 1
    fi
}

# Build principal
do_build() {
    log "🔨 Iniciando build do fork..."
    
    cd "$FORK_DIR"
    
    # Pull latest (se online e não --offline)
    if [ "${1:-}" != "--offline" ]; then
        if git remote update >/dev/null 2>&1; then
            git pull --ff-only origin "$(git rev-parse --abbrev-ref HEAD)" 2>/dev/null || log "⚠️ Pull falhou, usando código local"
        fi
    fi
    
    # Install deps
    log "📦 Instalando dependências..."
    pnpm install --frozen-lockfile
    
    # Build
    log "🏗️ Buildando..."
    pnpm build
    
    # Gerar checksum
    generate_checksum
    
    # Validar build
    log "🔍 Validando build..."
    local version
    version=$(node "$OPENCLAW_BIN" --version 2>/dev/null || echo "unknown")
    if [ "$version" != "unknown" ]; then
        log "✅ Build concluído: $version"
        return 0
    else
        log "❌ Build falhou na validação"
        return 1
    fi
}

# Executar com verificação de checksum
run_with_verify() {
    if verify_checksum; then
        exec node "$OPENCLAW_BIN" "$@"
    else
        log "🔴 Recusando executar binário com checksum inválido!"
        exit 1
    fi
}

# Verificar se Fallback L4 está bloqueado
check_fallback_l4_blocked() {
    if [ "${OPENCLAW_DISABLE_FALLBACK_L4:-}" = "true" ]; then
        log "🛡️ Fallback L4 (JS arbitrário) está BLOQUEADO"
        return 0
    else
        log "⚠️ Fallback L4 (JS arbitrário) está PERMITIDO - INSEGURO!"
        return 1
    fi
}

# Mostrar ajuda
show_help() {
    echo "OpenClaw Fork Build Script"
    echo ""
    echo "Uso: $0 [comando]"
    echo ""
    echo "Comandos:"
    echo "  build [--offline]  Build do fork (default)"
    echo "  verify             Verificar checksum do binário"
    echo "  checksum           Gerar checksum do binário atual"
    echo "  run [args]         Executar com verificação de checksum"
    echo "  check-l4           Verificar se Fallback L4 está bloqueado"
    echo "  help               Mostrar esta ajuda"
    echo ""
    echo "Variáveis de ambiente:"
    echo "  OPENCLAW_FORK_DIR  Diretório do fork (default: auto-detectado)"
}

# Comandos
case "${1:-build}" in
    build)
        shift || true
        do_build "$@"
        ;;
    verify)
        verify_checksum
        ;;
    checksum)
        generate_checksum
        ;;
    run)
        shift
        run_with_verify "$@"
        ;;
    check-l4)
        check_fallback_l4_blocked
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
