#!/usr/bin/env bash
#
# eko-build-swap.sh — Build fork + swap runtime
# Uso: ./scripts/eko-build-swap.sh
# Rollback: curl -fsSL https://openclaw.ai/install.sh | bash -s -- --no-onboard --no-prompt
#
set -euo pipefail

# ── Ensure ~/.local/bin in PATH (install.sh --git coloca o wrapper lá)
export PATH="$HOME/.local/bin:$PATH"

LOG="$HOME/openclaw/agents/eko/memory/logs/build-swap-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "$(dirname "$LOG")"

# Tee tudo para log + terminal
exec > >(tee -a "$LOG") 2>&1

echo "══════════════════════════════════════════════"
echo "  BUILD & SWAP — $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "══════════════════════════════════════════════"
echo ""

FORK_DIR="$HOME/openclaw/fork"
cd "$FORK_DIR"

# ── PRE-FLIGHT ──────────────────────────────────
echo "▶ [1/8] Pre-flight checks..."
echo "  Node:    $(node --version)"
echo "  pnpm:    $(pnpm --version)"
echo "  Git:     $(git log --oneline -1)"
echo "  Branch:  $(git branch --show-current)"
CURRENT_VERSION=$(openclaw --version 2>/dev/null || echo 'not found')
FORK_VERSION=$(node -e "console.log(require('./package.json').version)")
echo "  Current: $CURRENT_VERSION"
echo "  Fork:    $FORK_VERSION"
echo "  Which:   $(which openclaw 2>/dev/null || echo 'not found')"
echo ""

# ── VERIFY PATCHES ──────────────────────────────
echo "▶ [2/8] Verificando patches..."
if grep -q "selfPhoneMode" src/web/inbound/access-control.ts 2>/dev/null; then
  echo "  ✅ selfChatMode patch presente"
else
  echo "  ❌ ERRO: selfChatMode patch NÃO encontrado!"
  exit 1
fi

if grep -q "account_id" src/auto-reply/reply/inbound-meta.ts 2>/dev/null; then
  echo "  ✅ accountId patch presente"
else
  echo "  ❌ ERRO: accountId patch NÃO encontrado!"
  exit 1
fi
echo ""

# ── INSTALL DEPS ────────────────────────────────
echo "▶ [3/8] pnpm install..."
time pnpm install --frozen-lockfile 2>&1
echo ""

# ── BUILD ───────────────────────────────────────
echo "▶ [4/8] pnpm build..."
time pnpm build 2>&1
echo ""

# Verificar build output
if [ -f dist/entry.js ]; then
  FILE_COUNT=$(find dist -name '*.js' | wc -l | tr -d ' ')
  DIST_SIZE=$(du -sh dist | cut -f1)
  echo "  ✅ Build OK: $FILE_COUNT files, $DIST_SIZE total"
else
  echo "  ❌ ERRO: dist/entry.js não encontrado!"
  exit 1
fi
echo ""

# ── TESTS ───────────────────────────────────────
echo "▶ [5/8] Testes dos patches (rápido)..."
if pnpm vitest run src/web/inbound/access-control.test.ts src/auto-reply/reply/inbound-meta.test.ts 2>&1; then
  echo "  ✅ Testes dos patches PASSED"
else
  echo "  ⚠️ Testes falharam — verifique antes de prosseguir"
  echo "  Continuar mesmo assim? (Ctrl+C para abortar, Enter para continuar)"
  read -r
fi
echo ""

# ── STOP GATEWAY ────────────────────────────────
echo "▶ [6/8] Parando gateway..."
if command -v openclaw &>/dev/null; then
  openclaw gateway stop 2>&1 || true
else
  # Fallback: parar via launchctl direto
  launchctl bootout "gui/$(id -u)/ai.openclaw.gateway" 2>/dev/null || true
fi
sleep 2
echo "  Gateway parado."
echo ""

# ── SWAP (install.sh --git oficial) ─────────────
echo "▶ [7/8] install.sh --git (swap binário via método oficial)..."
curl -fsSL --proto '=https' --tlsv1.2 https://openclaw.ai/install.sh | bash -s -- \
  --git --git-dir "$FORK_DIR" --no-git-update --no-onboard --no-prompt 2>&1
echo ""

# Refresh PATH (install.sh pode ter mudado o wrapper)
hash -r 2>/dev/null || true

NEW_VERSION=$(openclaw --version 2>/dev/null || echo "ERRO")
echo "  Versão após swap: $NEW_VERSION"
echo "  which openclaw: $(which openclaw 2>/dev/null || echo 'not found')"
if [ "$NEW_VERSION" = "$CURRENT_VERSION" ] && [ "$NEW_VERSION" != "$FORK_VERSION" ]; then
  echo "  ⚠️ AVISO: Versão não mudou! Swap pode não ter funcionado."
fi
echo ""

# ── START GATEWAY ───────────────────────────────
echo "▶ [8/8] Reinstalando e iniciando gateway..."
# gateway install recria o LaunchAgent com os paths corretos
openclaw gateway install 2>&1 || true
sleep 3

# Verificar se subiu
if openclaw gateway status 2>&1 | grep -q "running"; then
  echo "  ✅ Gateway rodando"
else
  echo "  ⚠️ Gateway pode não ter iniciado. Verifique com: openclaw gateway status"
fi
echo ""

# ── RESULTADO FINAL ─────────────────────────────
echo "══════════════════════════════════════════════"
echo "  RESULTADO FINAL"
echo "══════════════════════════════════════════════"
echo "  Versão:  $(openclaw --version 2>/dev/null || echo 'ERRO')"
echo "  Which:   $(which openclaw 2>/dev/null || echo 'not found')"
echo "  Gateway: $(openclaw gateway status 2>&1 | grep -E 'running|loaded|not' | head -1 || echo 'verificar manualmente')"
echo ""
echo "  Log: $LOG"
echo ""
echo "  PRÓXIMO: Envie uma msg pelo WhatsApp para testar."
echo "  Rollback: curl -fsSL https://openclaw.ai/install.sh | bash -s -- --no-onboard --no-prompt"
echo "══════════════════════════════════════════════"
