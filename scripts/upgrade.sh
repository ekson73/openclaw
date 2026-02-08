#!/usr/bin/env bash
#
# OpenClaw Fork Upgrade Script
# Updates the fork and reinstalls
#
# Usage:
#   ./scripts/upgrade.sh [options]
#
# Options:
#   --dry-run       Show what would be done without executing
#   --force         Skip confirmation prompts
#   --upstream      Sync with upstream before upgrading
#   --no-restart    Don't restart gateway after upgrade
#   --help          Show this help message
#
# Environment Variables:
#   OPENCLAW_FORK_DIR    Fork directory (default: auto-detect)
#

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DRY_RUN=false
FORCE=false
SYNC_UPSTREAM=false
RESTART_GATEWAY=true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPENCLAW_FORK_DIR="${OPENCLAW_FORK_DIR:-$(dirname "$SCRIPT_DIR")}"

log() { echo -e "${BLUE}[upgrade]${NC} $*"; }
log_ok() { echo -e "${GREEN}[upgrade]${NC} ✓ $*"; }
log_warn() { echo -e "${YELLOW}[upgrade]${NC} ⚠ $*"; }
log_error() { echo -e "${RED}[upgrade]${NC} ✗ $*"; }

usage() { head -22 "$0" | grep "^#" | sed 's/^# \?//'; exit 0; }

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=true; shift ;;
        --force) FORCE=true; shift ;;
        --upstream) SYNC_UPSTREAM=true; shift ;;
        --no-restart) RESTART_GATEWAY=false; shift ;;
        --help|-h) usage ;;
        *) log_error "Unknown option: $1"; usage ;;
    esac
done

[[ ! -f "$OPENCLAW_FORK_DIR/package.json" ]] && { log_error "Not a valid OpenClaw directory"; exit 1; }

cd "$OPENCLAW_FORK_DIR"
OLD_VERSION=$(grep '"version"' package.json | head -1 | sed 's/.*"version": *"\([^"]*\)".*/\1/')
log "OpenClaw Fork Upgrader"
log "Fork directory: $OPENCLAW_FORK_DIR"
log "Current version: $OLD_VERSION"
echo

check_git() {
    log "Checking git status..."
    if ! git diff --quiet 2>/dev/null; then
        log_warn "Uncommitted changes detected"
        $FORCE || { read -p "Continue? [y/N] " -n 1 -r; echo; [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0; }
    fi
    log_ok "Git OK"
}

sync_upstream() {
    $SYNC_UPSTREAM || return
    log "Syncing with upstream..."
    $DRY_RUN && { log "[dry-run] Would fetch and merge upstream/main"; return; }
    git remote get-url upstream >/dev/null 2>&1 || { log_warn "No upstream remote"; return; }
    git fetch upstream
    [[ "$(git branch --show-current)" == "main" ]] && git merge upstream/main --no-edit || log_warn "Not on main, skip merge"
    log_ok "Upstream sync complete"
}

pull_changes() {
    log "Pulling latest..."
    $DRY_RUN && { log "[dry-run] Would run: git pull"; return; }
    git pull --ff-only || log_warn "Fast-forward failed"
    log_ok "Pull complete"
}

rebuild() {
    log "Rebuilding..."
    $DRY_RUN && { log "[dry-run] Would run: npm install && npm run build"; return; }
    rm -rf node_modules
    npm install
    npm run build
    log_ok "Rebuild complete"
}

reinstall() {
    log "Reinstalling..."
    $DRY_RUN && { log "[dry-run] Would run: npm link"; return; }
    npm link
    log_ok "Reinstall complete"
}

restart_gw() {
    $RESTART_GATEWAY || return
    log "Checking gateway..."
    $DRY_RUN && { log "[dry-run] Would restart gateway if running"; return; }
    pgrep -f "openclaw.*gateway" >/dev/null 2>&1 && { log "Restarting gateway..."; openclaw gateway restart 2>/dev/null || log_warn "Could not restart"; } || log "Gateway not running"
}

confirm() {
    $FORCE && return 0
    echo
    read -p "Proceed with upgrade? [y/N] " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && { log "Aborted."; exit 0; }
}

main() {
    $DRY_RUN && { log_warn "DRY RUN MODE"; echo; }
    check_git
    confirm
    sync_upstream
    pull_changes
    rebuild
    reinstall
    restart_gw
    NEW_VERSION=$(grep '"version"' package.json | head -1 | sed 's/.*"version": *"\([^"]*\)".*/\1/')
    echo
    log "Upgrade complete! $OLD_VERSION → $NEW_VERSION"
}

main "$@"
