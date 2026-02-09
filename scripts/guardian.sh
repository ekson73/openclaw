#!/bin/bash
#===============================================================================
# OPENCLAW GUARDIAN
# Monitora gateway e executa recovery automático se falhar
#
# Uso: ./scripts/guardian.sh [start|stop|status]
#===============================================================================

# PATH explícito para funcionar via launchd (que tem PATH mínimo)
export PATH="${HOME}/.volta/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

set -euo pipefail

# Auto-detectar diretórios
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORK_DIR="${OPENCLAW_FORK_DIR:-$(dirname "$SCRIPT_DIR")}"

# Configurações (podem ser sobrescritas por variáveis de ambiente)
LOG_DIR="${HOME}/.openclaw/logs"
LOG_FILE="${LOG_DIR}/guardian.log"
PID_FILE="${HOME}/.openclaw/guardian.pid"
HEALTH_CHECK_INTERVAL="${OPENCLAW_GUARDIAN_INTERVAL:-10}"     # segundos entre checks
MAX_FAILURES="${OPENCLAW_GUARDIAN_MAX_FAILURES:-3}"           # falhas consecutivas antes de recovery
STARTUP_GRACE_PERIOD="${OPENCLAW_GUARDIAN_GRACE:-30}"         # segundos após restart para ignorar falhas
NOTIFY_TARGET="${OPENCLAW_GUARDIAN_NOTIFY:-}"                 # número para notificar (opcional)

# Criar diretórios se não existirem
mkdir -p "$LOG_DIR"

# Auto-detectar binário OpenClaw
if command -v openclaw &>/dev/null; then
    OPENCLAW_BIN="openclaw"
elif [ -x "${HOME}/.volta/bin/openclaw" ]; then
    OPENCLAW_BIN="${HOME}/.volta/bin/openclaw"
else
    echo "❌ OpenClaw não encontrado"
    exit 1
fi

# Estado
failure_count=0
last_restart_time=0

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

health_check() {
    # Usar script de health check se existir
    if [ -x "${SCRIPT_DIR}/health-check.sh" ]; then
        if "${SCRIPT_DIR}/health-check.sh" full >/dev/null 2>&1; then
            return 0
        fi
    else
        # Fallback: verificar diretamente
        if $OPENCLAW_BIN gateway status >/dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

do_recovery() {
    log "🔴 INICIANDO RECOVERY AUTOMÁTICO"
    
    # Parar gateway
    log "⏹️ Parando gateway..."
    $OPENCLAW_BIN gateway stop 2>/dev/null || true
    sleep 2
    
    # Reiniciar gateway
    log "▶️ Iniciando gateway..."
    $OPENCLAW_BIN gateway start 2>/dev/null || true
    
    # Aguardar startup
    log "⏳ Aguardando startup (${STARTUP_GRACE_PERIOD}s)..."
    sleep "$STARTUP_GRACE_PERIOD"
    
    # Verificar saúde
    if health_check; then
        log "✅ Recovery concluído com sucesso"
        last_restart_time=$(date +%s)
        failure_count=0
        return 0
    else
        log "❌ Recovery falhou no health check"
        return 1
    fi
}

notify_owner() {
    local message="$1"
    
    # Notificar apenas se target configurado
    if [ -n "$NOTIFY_TARGET" ]; then
        $OPENCLAW_BIN message send --channel whatsapp \
            --target "$NOTIFY_TARGET" \
            --message "🚨 GUARDIAN: $message" 2>/dev/null || true
        log "📱 Notificação enviada para $NOTIFY_TARGET"
    fi
    
    log "📢 $message"
}

main_loop() {
    log "🛡️ Guardian iniciado (PID: $$)"
    log "   Intervalo: ${HEALTH_CHECK_INTERVAL}s"
    log "   Max falhas: ${MAX_FAILURES}"
    log "   Grace period: ${STARTUP_GRACE_PERIOD}s"
    echo $$ > "$PID_FILE"
    
    while true; do
        current_time=$(date +%s)
        
        # Grace period após restart
        if (( current_time - last_restart_time < STARTUP_GRACE_PERIOD )); then
            sleep "$HEALTH_CHECK_INTERVAL"
            continue
        fi
        
        # Health check
        if health_check; then
            failure_count=0
        else
            ((failure_count++)) || true
            log "⚠️ Health check falhou ($failure_count/$MAX_FAILURES)"
            
            if (( failure_count >= MAX_FAILURES )); then
                notify_owner "Gateway falhou $MAX_FAILURES vezes consecutivas. Iniciando recovery."
                do_recovery
            fi
        fi
        
        sleep "$HEALTH_CHECK_INTERVAL"
    done
}

show_help() {
    echo "OpenClaw Guardian - Watchdog para o Gateway"
    echo ""
    echo "Uso: $0 [comando]"
    echo ""
    echo "Comandos:"
    echo "  start   Iniciar guardian (default)"
    echo "  stop    Parar guardian"
    echo "  status  Ver status do guardian"
    echo ""
    echo "Variáveis de ambiente:"
    echo "  OPENCLAW_GUARDIAN_INTERVAL      Intervalo entre checks (default: 10)"
    echo "  OPENCLAW_GUARDIAN_MAX_FAILURES  Falhas antes de recovery (default: 3)"
    echo "  OPENCLAW_GUARDIAN_GRACE         Grace period após restart (default: 30)"
    echo "  OPENCLAW_GUARDIAN_NOTIFY        Número WhatsApp para notificações"
}

# Comandos
case "${1:-start}" in
    start)
        if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            log "Guardian já está rodando (PID: $(cat "$PID_FILE"))"
            exit 0
        fi
        main_loop
        ;;
    stop)
        if [ -f "$PID_FILE" ]; then
            kill "$(cat "$PID_FILE")" 2>/dev/null || true
            rm -f "$PID_FILE"
            log "Guardian parado"
        else
            echo "Guardian não está rodando"
        fi
        ;;
    status)
        if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            echo "🟢 Guardian rodando (PID: $(cat "$PID_FILE"))"
            exit 0
        else
            echo "🔴 Guardian não está rodando"
            exit 1
        fi
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
