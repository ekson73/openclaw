#!/bin/bash
# setup-worktree.sh - Create a new worktree for feature/fix work
# 
# Usage: ./scripts/setup-worktree.sh <type> <name> [base-branch]
#   type: feat | fix | hotfix
#   name: feature/fix name (kebab-case)
#   base-branch: branch to base off (default: develop)
#
# Examples:
#   ./scripts/setup-worktree.sh feat skill-pomodoro
#   ./scripts/setup-worktree.sh fix memory-leak develop
#   ./scripts/setup-worktree.sh hotfix security-patch main

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Find repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Parse arguments
TYPE="${1:-}"
NAME="${2:-}"
BASE_BRANCH="${3:-develop}"

# Validate arguments
if [[ -z "$TYPE" || -z "$NAME" ]]; then
    echo -e "${RED}Usage: $0 <type> <name> [base-branch]${NC}"
    echo ""
    echo "Types: feat, fix, hotfix"
    echo "Example: $0 feat skill-pomodoro"
    exit 1
fi

# Validate type
case "$TYPE" in
    feat|fix|hotfix)
        ;;
    *)
        echo -e "${RED}Invalid type: $TYPE${NC}"
        echo "Valid types: feat, fix, hotfix"
        exit 1
        ;;
esac

# Validate NAME (prevent path traversal)
if [[ "$NAME" =~ \.\./ ]] || [[ "$NAME" =~ ^/ ]] || [[ "$NAME" =~ [[:space:]] ]]; then
    echo -e "${RED}Invalid name: $NAME${NC}"
    echo "Name cannot contain '../', start with '/', or contain spaces"
    exit 1
fi

# Validate NAME format (kebab-case only)
if ! [[ "$NAME" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    echo -e "${YELLOW}Warning: Name '$NAME' is not kebab-case${NC}"
    echo "Recommended format: lowercase-with-dashes (e.g., my-feature)"
fi

# Construct branch and worktree names
BRANCH_NAME="${TYPE}/${NAME}"
WORKTREE_DIR=".worktrees/${TYPE}-${NAME}"
FULL_WORKTREE_PATH="${REPO_ROOT}/${WORKTREE_DIR}"

echo -e "${GREEN}=== Creating Worktree ===${NC}"
echo "Type: $TYPE"
echo "Name: $NAME"
echo "Branch: $BRANCH_NAME"
echo "Base: $BASE_BRANCH"
echo "Path: $WORKTREE_DIR"
echo ""

# Check if worktree already exists
if [[ -d "$FULL_WORKTREE_PATH" ]]; then
    echo -e "${YELLOW}Worktree already exists: $WORKTREE_DIR${NC}"
    echo "Use: cd $FULL_WORKTREE_PATH"
    exit 0
fi

# Check if branch already exists
cd "$REPO_ROOT"
if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
    echo -e "${YELLOW}Branch already exists, creating worktree for existing branch...${NC}"
    git worktree add "$WORKTREE_DIR" "$BRANCH_NAME"
else
    echo "Creating new branch based on $BASE_BRANCH..."
    git worktree add "$WORKTREE_DIR" -b "$BRANCH_NAME" "$BASE_BRANCH"
fi

# Update sessions.json if it exists
SESSIONS_FILE="${REPO_ROOT}/.worktrees/sessions.json"
if [[ -f "$SESSIONS_FILE" ]]; then
    echo -e "${GREEN}Updating sessions.json...${NC}"
    # Use jq if available, otherwise skip
    if command -v jq &> /dev/null; then
        TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        AGENT_NAME="${OPENCLAW_AGENT_NAME:-unknown}"
        
        # Create new session entry
        NEW_SESSION=$(cat <<EOF
{
  "session_id": "${AGENT_NAME}-${NAME}",
  "agent_name": "${AGENT_NAME}",
  "started_at": "${TIMESTAMP}",
  "last_heartbeat": "${TIMESTAMP}",
  "worktree_path": "${WORKTREE_DIR}",
  "branch": "${BRANCH_NAME}",
  "parent_branch": "${BASE_BRANCH}",
  "working_on": [],
  "status": "active",
  "notes": "Created by setup-worktree.sh"
}
EOF
)
        # Add to active_sessions
        jq --argjson session "$NEW_SESSION" '.active_sessions += [$session] | .last_updated = (now | todate)' "$SESSIONS_FILE" > "${SESSIONS_FILE}.tmp" && mv "${SESSIONS_FILE}.tmp" "$SESSIONS_FILE"
        echo -e "${GREEN}✓ Session added to sessions.json${NC}"
    else
        echo -e "${YELLOW}jq not found, skipping sessions.json update${NC}"
    fi
fi

# Create LINEAGE.md in the new worktree
LINEAGE_FILE="${FULL_WORKTREE_PATH}/LINEAGE.md"
AGENT_NAME="${OPENCLAW_AGENT_NAME:-unknown}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

cat > "$LINEAGE_FILE" << EOF
# LINEAGE.md

## Origem
- **Criado por:** ${AGENT_NAME}
- **Parent session:** ${OPENCLAW_SESSION_ID:-main}
- **Data:** ${TIMESTAMP}
- **Branch base:** ${BASE_BRANCH}

## Objetivo
<!-- Descreva o objetivo desta branch -->

## Arquivos Principais
<!-- Liste os arquivos principais que serão modificados -->

## Dependências
- Depende de: <!-- outras branches/PRs -->
- Bloqueado por: <!-- issues/decisões pendentes -->

## Status
- [ ] Implementação
- [ ] Testes
- [ ] Documentação
- [ ] PR criado
- [ ] Review aprovado

---
*Gerado automaticamente por setup-worktree.sh*
EOF

echo -e "${GREEN}✓ LINEAGE.md criado${NC}"

echo ""
echo -e "${GREEN}=== Worktree Created ===${NC}"
echo ""
echo "Next steps:"
echo "  1. cd $FULL_WORKTREE_PATH"
echo "  2. Edit LINEAGE.md with your objective"
echo "  3. Make your changes"
echo "  4. git add . && git commit -m \"$TYPE: description\""
echo "  5. git push origin $BRANCH_NAME"
echo "  6. gh pr create --base develop"
echo ""
echo "When done:"
echo "  git worktree remove $WORKTREE_DIR"
echo "  git branch -d $BRANCH_NAME"
