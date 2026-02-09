#!/bin/bash
#===============================================================================
# OPENCLAW GATEWAY START
# Iniciar gateway com fallback multi-nível (sem L4 por segurança)
#
# Níveis de fallback:
#   0. Build local (fork) com verificação de checksum
#   1. Recovery (restart gateway)
#   2. Volta (se instalado)
#   3. npm global (se instalado)
#   4. BLOQUEADO (execução de JS arbitrário)
#
# Uso: ./scripts/gateway-start.sh
#===============================================================================

set -euo pipefail

# PATH explícito
export PATH="${HOME}/.volta/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

# Auto-detectar diretório do fork
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORK_DIR="${OPENCLAW_FORK_DIR:-$(dirname "$SCRIPT_DIR")}"

# Configurações
FORK_BIN="${FORK_DIR}/dist/openclaw.mjs"
LOG_DIR="${HOME}/.openclaw/logs"
LOG_FILE="${LOG_DIR}/gateway-start.log"

# Segurança: DESABILITAR Fallback L4 por padrão
export OPENCLAW_DISABLE_FALLBACK_L4="true"

mkdir -p "$LOG_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$USER]" "$@" | tee -a "$LOG_FILE"
}

#-------------------------------------------------------------------------------
# NÍVEL 0: Build local com verificação de checksum
#-------------------------------------------------------------------------------
if [ -f "$FORK_BIN" ]; then
    log "🔍 Verificando checksum do build local..."
    if "${SCRIPT_DIR}/build.sh" verify 2>/dev/null; then
        log "🟢 Iniciando do build local - checksum OK"
        exec node "$FORK_BIN" gateway start
    else
        log "⚠️ Checksum inválido, tentando rebuild..."
        if "${SCRIPT_DIR}/build.sh" build; then
            log "🟢 Rebuild OK, iniciando..."
            exec node "$FORK_BIN" gateway start
        fi
    fi
fi

#-------------------------------------------------------------------------------
# NÍVEL 1: Recovery (restart)
#-------------------------------------------------------------------------------
log "🟡 Nível 0 falhou, tentando recovery (Nível 1)..."
if command -v openclaw &>/dev/null; then
    log "🔄 Parando gateway existente..."
    openclaw gateway stop 2>/dev/null || true
    sleep 2
    log "▶️ Reiniciando gateway..."
    exec openclaw gateway start
fi

#-------------------------------------------------------------------------------
# NÍVEL 2: Volta
#-------------------------------------------------------------------------------
log "🟠 Nível 1 falhou, tentando Volta (Nível 2)..."
if command -v volta &> /dev/null; then
    log "🟢 Iniciando via Volta..."
    exec volta run openclaw gateway start
fi

#-------------------------------------------------------------------------------
# NÍVEL 3: npm global
#-------------------------------------------------------------------------------
log "🟠 Nível 2 falhou, tentando npm global (Nível 3)..."
if command -v openclaw &> /dev/null; then
    local_bin=$(command -v openclaw)
    log "🟢 Iniciando via npm global: $local_bin"
    exec openclaw gateway start
fi

#-------------------------------------------------------------------------------
# NÍVEL 4: BLOQUEADO (segurança)
#-------------------------------------------------------------------------------
log "🔴 TODOS OS FALLBACKS FALHARAM"
log "🔴 Nível 4 (Node direto) está DESABILITADO por segurança"
log ""
log "Ações manuais necessárias:"
log "  1. Verificar o fork: $FORK_DIR"
log "  2. Executar: ${SCRIPT_DIR}/build.sh build"
log "  3. Ou reinstalar: npm install -g openclaw"

exit 1
