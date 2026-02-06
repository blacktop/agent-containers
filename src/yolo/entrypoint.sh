#!/bin/bash
# =============================================================================
# Yolo Mode Entrypoint
# =============================================================================
# Initializes firewall (if enabled) and dispatches to AI agents with yolo flags.
# =============================================================================

set -e

# ------------------------------------
# Firewall Initialization
# ------------------------------------
if [ "${FIREWALL_ENABLED:-true}" = "true" ]; then
    if command -v iptables &>/dev/null && sudo iptables -L &>/dev/null 2>&1; then
        echo "Initializing firewall..."
        sudo /usr/local/bin/init-firewall
    else
        echo "Note: Firewall skipped (no NET_ADMIN capability)"
    fi
fi

# ------------------------------------
# Git Identity
# ------------------------------------
if [ -n "${GIT_USER_NAME:-}" ]; then
    git config --global user.name "$GIT_USER_NAME"
fi
if [ -n "${GIT_USER_EMAIL:-}" ]; then
    git config --global user.email "$GIT_USER_EMAIL"
fi

# ------------------------------------
# GitHub App Authentication
# ------------------------------------
if [ -n "${GITHUB_APP_ID:-}" ]; then
    /usr/local/bin/init-github-app.sh || echo "Warning: GitHub App auth failed (continuing anyway)"
fi

# ------------------------------------
# MCP Server Configuration
# ------------------------------------
if [ -n "${CONTEXT7_API_KEY:-}" ] || [ -n "${EXA_API_KEY:-}" ]; then
    /usr/local/bin/init-mcp.sh 2>/dev/null || true
fi

# ------------------------------------
# Agent Dispatch
# ------------------------------------
CMD="${1:-bash}"
shift 2>/dev/null || true

case "$CMD" in
    claude|claude-code)
        echo "Starting Claude Code (yolo mode)..."
        exec claude --dangerously-skip-permissions "$@"
        ;;
    codex)
        echo "Starting Codex (full-auto mode)..."
        exec codex --approval-mode full-auto --full-auto-error-mode ignore-and-continue "$@"
        ;;
    gemini)
        echo "Starting Gemini CLI (yolo mode)..."
        # Initialize extensions on first run
        /usr/local/bin/init-gemini-extensions.sh 2>/dev/null || true
        exec gemini --yolo "$@"
        ;;
    install-all)
        echo "All agents are pre-installed in this image."
        echo ""
        echo "Available agents:"
        echo "  claude  - Claude Code (--dangerously-skip-permissions)"
        echo "  codex   - Codex (--approval-mode full-auto)"
        echo "  gemini  - Gemini CLI (--yolo)"
        echo ""
        echo "Versions:"
        claude --version 2>/dev/null || echo "  claude: not found"
        codex --version 2>/dev/null || echo "  codex: not found"
        gemini --version 2>/dev/null || echo "  gemini: not found"
        exit 0
        ;;
    fish)
        exec fish "$@"
        ;;
    bash|sh)
        exec bash "$@"
        ;;
    *)
        # Run arbitrary command
        exec "$CMD" "$@"
        ;;
esac
