#!/usr/bin/env bash
#
# OpenClaw Fork Install Script
# Installs OpenClaw from a local fork directory
#
# Usage:
#   ./scripts/install.sh [options]
#
# Options:
#   --dry-run       Show what would be done without executing
#   --force         Skip confirmation prompts
#   --help          Show this help message
#
# Environment Variables:
#   OPENCLAW_FORK_DIR    Fork directory (default: auto-detect from script location)
#

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DRY_RUN=false
FORCE=false

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPENCLAW_FORK_DIR="${OPENCLAW_FORK_DIR:-$(dirname "$SCRIPT_DIR")}"

log() { echo -e "${BLUE}[install]${NC} $*"; }
log_ok() { echo -e "${GREEN}[install]${NC} ✓ $*"; }
log_warn() { echo -e "${YELLOW}[install]${NC} ⚠ $*"; }
log_error() { echo -e "${RED}[install]${NC} ✗ $*"; }

usage() { head -20 "$0" | grep "^#" | sed 's/^# \?//'; exit 0; }

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=true; shift ;;
        --force) FORCE=true; shift ;;
        --help|-h) usage ;;
        *) log_error "Unknown option: $1"; usage ;;
    esac
done

[[ ! -f "$OPENCLAW_FORK_DIR/package.json" ]] && { log_error "Not a valid OpenClaw directory: $OPENCLAW_FORK_DIR"; exit 1; }

VERSION=$(grep '"version"' "$OPENCLAW_FORK_DIR/package.json" | head -1 | sed 's/.*"version": *"\([^"]*\)".*/\1/')
log "OpenClaw Fork Installer"
log "Fork directory: $OPENCLAW_FORK_DIR"
log "Version: $VERSION"
echo

check_prereqs() {
    log "Checking prerequisites..."
    command -v node >/dev/null 2>&1 || { log_error "Node.js not found"; exit 1; }
    command -v npm >/dev/null 2>&1 || { log_error "npm not found"; exit 1; }
    NODE_VERSION=$(node -v | sed 's/v//' | cut -d. -f1)
    [[ $NODE_VERSION -lt 20 ]] && { log_error "Node.js 20+ required, found: $(node -v)"; exit 1; }
    log_ok "Node $(node -v), npm $(npm -v)"
}

build_fork() {
    log "Building fork..."
    $DRY_RUN && { log "[dry-run] Would run: npm install && npm run build"; return; }
    cd "$OPENCLAW_FORK_DIR"
    [[ ! -d "node_modules" ]] && { log "Installing dependencies..."; npm install; }
    log "Compiling TypeScript..."
    npm run build
    log_ok "Build complete"
}

install_global() {
    log "Installing globally..."
    $DRY_RUN && { log "[dry-run] Would run: npm link"; return; }
    cd "$OPENCLAW_FORK_DIR"
    npm unlink -g openclaw 2>/dev/null || true
    npm link
    command -v openclaw >/dev/null 2>&1 && log_ok "Installed: openclaw $(openclaw --version 2>/dev/null | tail -1)" || log_warn "openclaw not in PATH"
}

confirm() {
    $FORCE && return 0
    echo
    read -p "Proceed with installation? [y/N] " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && { log "Aborted."; exit 0; }
}

main() {
    $DRY_RUN && { log_warn "DRY RUN MODE"; echo; }
    check_prereqs
    confirm
    build_fork
    install_global
    echo
    log "Installation complete!"
    echo "  Run 'openclaw --version' to verify."
}

main "$@"
