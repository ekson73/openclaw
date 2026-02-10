#!/bin/bash
#===============================================================================
# OPENCLAW HEALTH CHECK
# Health check com critérios explícitos para monitoramento
#
# Uso: ./scripts/health-check.sh [full|quick|gateway|whatsapp|process|binary]
#===============================================================================

# PATH explícito para funcionar via launchd (que tem PATH mínimo)
export PATH="${HOME}/.volta/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

set -euo pipefail

# Auto-detectar binário OpenClaw
if command -v openclaw &>/dev/null; then
    OPENCLAW_BIN="$(command -v openclaw)"
elif [ -x "${HOME}/.volta/bin/openclaw" ]; then
    OPENCLAW_BIN="${HOME}/.volta/bin/openclaw"
elif [ -x "${OPENCLAW_FORK_DIR:-}/dist/openclaw.mjs" ]; then
    OPENCLAW_BIN="node ${OPENCLAW_FORK_DIR}/dist/openclaw.mjs"
else
    echo "❌ OpenClaw não encontrado"
    exit 1
fi

TIMEOUT_SECONDS="${OPENCLAW_HEALTH_TIMEOUT:-10}"

# Health Check: Gateway está respondendo
health_check_gateway() {
    local exit_code=0
    # Capturar exit code explicitamente (evita problemas com set -e e timeout)
    timeout "$TIMEOUT_SECONDS" $OPENCLAW_BIN gateway status >/dev/null 2>&1 || exit_code=$?
    
    if [ "$exit_code" -eq 0 ]; then
        echo "✅ Gateway OK"
        return 0
    else
        echo "❌ Gateway não está respondendo (exit: $exit_code)"
        return 1
    fi
}

# Health Check: WhatsApp conectado (pelo menos uma conta)
health_check_whatsapp() {
    local status
    local exit_code=0
    # Usar openclaw status para ver channels
    # Timeout de 15s porque status pode demorar
    status=$(timeout 15 $OPENCLAW_BIN status 2>/dev/null) || exit_code=$?
    
    if [ "$exit_code" -eq 124 ]; then
        echo "⚠️ WhatsApp check timeout"
        return 1
    fi
    
    # Procurar por "WhatsApp" com "OK" ou "linked" na mesma linha
    if echo "$status" | grep -i "whatsapp" | grep -qiE "OK|linked"; then
        echo "✅ WhatsApp conectado"
        return 0
    else
        echo "❌ WhatsApp desconectado"
        return 1
    fi
}

# Health Check: Processo gateway está rodando
health_check_process() {
    local result
    result=$(ps aux 2>/dev/null | grep "[o]penclaw-gateway" || true)
    if [[ -n "$result" ]]; then
        echo "✅ Processo gateway ativo"
        return 0
    else
        echo "❌ Processo gateway não encontrado"
        return 1
    fi
}

# Health Check: Binário existe e é executável
health_check_binary() {
    if $OPENCLAW_BIN --version >/dev/null 2>&1; then
        echo "✅ Binário OK"
        return 0
    else
        echo "❌ Binário não encontrado ou não executável"
        return 1
    fi
}

# Health Check Completo (usado pelo Guardian)
health_check_full() {
    local failures=0
    
    health_check_binary   || ((failures++))
    health_check_process  || ((failures++))
    health_check_gateway  || ((failures++))
    # WhatsApp é crítico mas pode ter delay na conexão
    health_check_whatsapp || echo "⚠️ WhatsApp check falhou (não crítico)"
    
    if (( failures > 0 )); then
        echo "❌ Health check falhou ($failures checks críticos)"
        return 1
    fi
    
    echo "✅ Todos os health checks passaram"
    return 0
}

# Health Check Rápido (só processo)
health_check_quick() {
    health_check_process
}

# Mostrar ajuda
show_help() {
    echo "OpenClaw Health Check"
    echo ""
    echo "Uso: $0 [comando]"
    echo ""
    echo "Comandos:"
    echo "  full      Health check completo (default)"
    echo "  quick     Apenas verifica processo"
    echo "  gateway   Verifica se gateway responde"
    echo "  whatsapp  Verifica conexão WhatsApp"
    echo "  process   Verifica se processo está rodando"
    echo "  binary    Verifica se binário existe"
    echo ""
    echo "Variáveis de ambiente:"
    echo "  OPENCLAW_HEALTH_TIMEOUT  Timeout em segundos (default: 10)"
}

# Execução
case "${1:-full}" in
    full)    health_check_full ;;
    quick)   health_check_quick ;;
    gateway) health_check_gateway ;;
    whatsapp) health_check_whatsapp ;;
    process) health_check_process ;;
    binary)  health_check_binary ;;
    help|--help|-h) show_help ;;
    *)
        echo "Comando desconhecido: $1"
        show_help
        exit 1
        ;;
esac
