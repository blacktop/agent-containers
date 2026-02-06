#!/bin/bash
# =============================================================================
# install-anchor.sh - Setup pf anchor for AI agent firewall
# =============================================================================
# Creates a pf anchor that can be enabled/disabled independently of system rules.
# Requires sudo.
#
# Usage:
#   sudo ./install-anchor.sh          # Install and enable
#   sudo ./install-anchor.sh disable  # Disable anchor
#   sudo ./install-anchor.sh status   # Check status
#   sudo ./install-anchor.sh refresh  # Refresh IP tables
# =============================================================================

set -e

ANCHOR_NAME="com.apple/agent"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PF_CONF="$SCRIPT_DIR/agent.pf.conf"

# Check for root
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script requires sudo"
    echo "Usage: sudo $0 [enable|disable|status|refresh]"
    exit 1
fi

# Resolve domain to IPs
resolve_domain() {
    local domain="$1"
    dig +short "$domain" A 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' || true
}

# Populate IP tables
populate_tables() {
    echo "Resolving domain IPs..."

    # GitHub IPs from API
    echo "  Fetching GitHub IP ranges..."
    GITHUB_META=$(curl -sf https://api.github.com/meta 2>/dev/null || echo '{}')

    # Create temp files for IPs
    GITHUB_IPS=$(mktemp)
    ALLOWED_IPS=$(mktemp)
    trap "rm -f $GITHUB_IPS $ALLOWED_IPS" EXIT

    # GitHub API ranges
    for key in hooks git packages pages importer actions dependabot copilot; do
        echo "$GITHUB_META" | jq -r ".${key}[]? // empty" 2>/dev/null >> "$GITHUB_IPS"
    done

    # GitHub domains
    for domain in github.com api.github.com raw.githubusercontent.com ghcr.io \
                  pkg-containers.githubusercontent.com objects.githubusercontent.com; do
        for ip in $(resolve_domain "$domain"); do
            echo "$ip/32" >> "$GITHUB_IPS"
        done
    done

    # npm
    echo "  Resolving npm..."
    for domain in registry.npmjs.org registry.yarnpkg.com; do
        for ip in $(resolve_domain "$domain"); do
            echo "$ip/32" >> "$ALLOWED_IPS"
        done
    done

    # PyPI
    echo "  Resolving PyPI..."
    for domain in pypi.org files.pythonhosted.org pypi.python.org; do
        for ip in $(resolve_domain "$domain"); do
            echo "$ip/32" >> "$ALLOWED_IPS"
        done
    done

    # crates.io
    echo "  Resolving crates.io..."
    for domain in crates.io static.crates.io index.crates.io static.rust-lang.org; do
        for ip in $(resolve_domain "$domain"); do
            echo "$ip/32" >> "$ALLOWED_IPS"
        done
    done

    # Go proxy
    echo "  Resolving Go proxy..."
    for domain in proxy.golang.org sum.golang.org storage.googleapis.com; do
        for ip in $(resolve_domain "$domain"); do
            echo "$ip/32" >> "$ALLOWED_IPS"
        done
    done

    # Anthropic
    echo "  Resolving Anthropic..."
    for domain in api.anthropic.com claude.ai console.anthropic.com statsig.anthropic.com; do
        for ip in $(resolve_domain "$domain"); do
            echo "$ip/32" >> "$ALLOWED_IPS"
        done
    done

    # OpenAI
    echo "  Resolving OpenAI..."
    for domain in api.openai.com platform.openai.com chat.openai.com chatgpt.com \
                  openai.com auth.openai.com; do
        for ip in $(resolve_domain "$domain"); do
            echo "$ip/32" >> "$ALLOWED_IPS"
        done
    done

    # Google AI
    echo "  Resolving Google AI..."
    for domain in generativelanguage.googleapis.com aiplatform.googleapis.com \
                  aistudio.google.com accounts.google.com oauth2.googleapis.com; do
        for ip in $(resolve_domain "$domain"); do
            echo "$ip/32" >> "$ALLOWED_IPS"
        done
    done

    # Debian/Ubuntu
    echo "  Resolving Debian/Ubuntu..."
    for domain in deb.debian.org security.debian.org archive.ubuntu.com security.ubuntu.com; do
        for ip in $(resolve_domain "$domain"); do
            echo "$ip/32" >> "$ALLOWED_IPS"
        done
    done

    # Always allowed
    echo "  Resolving always-allowed services..."
    for domain in sentry.io context7.com mcp.context7.com astral.sh; do
        for ip in $(resolve_domain "$domain"); do
            echo "$ip/32" >> "$ALLOWED_IPS"
        done
    done

    # Load tables
    echo "Loading IP tables..."

    # Flush and reload tables
    pfctl -a "$ANCHOR_NAME" -t github_ips -T flush 2>/dev/null || true
    pfctl -a "$ANCHOR_NAME" -t allowed_ips -T flush 2>/dev/null || true

    # Add IPs to tables
    if [ -s "$GITHUB_IPS" ]; then
        sort -u "$GITHUB_IPS" | while read -r cidr; do
            [ -n "$cidr" ] && pfctl -a "$ANCHOR_NAME" -t github_ips -T add "$cidr" 2>/dev/null || true
        done
    fi

    if [ -s "$ALLOWED_IPS" ]; then
        sort -u "$ALLOWED_IPS" | while read -r cidr; do
            [ -n "$cidr" ] && pfctl -a "$ANCHOR_NAME" -t allowed_ips -T add "$cidr" 2>/dev/null || true
        done
    fi

    echo "Tables populated."
}

# Enable anchor
enable_anchor() {
    echo "Enabling pf anchor: $ANCHOR_NAME"

    # Check if anchor already in pf.conf
    if ! grep -q "anchor \"$ANCHOR_NAME\"" /etc/pf.conf 2>/dev/null; then
        echo "Adding anchor to /etc/pf.conf..."
        # Backup
        cp /etc/pf.conf /etc/pf.conf.backup
        # Add anchor (after existing anchors)
        echo "anchor \"$ANCHOR_NAME\"" >> /etc/pf.conf
    fi

    # Load rules into anchor
    if [ -f "$PF_CONF" ]; then
        local agent_user agent_uid
        agent_user="${SUDO_USER:-$USER}"
        agent_uid="$(id -u "$agent_user" 2>/dev/null)" || {
            echo "Error: Failed to resolve uid for user: $agent_user"
            exit 1
        }

        echo "Loading rules from $PF_CONF..."
        pfctl -a "$ANCHOR_NAME" -D agent_uid="$agent_uid" -f "$PF_CONF"
    fi

    # Populate IP tables
    populate_tables

    # Enable pf if not already enabled
    if ! pfctl -s info | grep -q "Status: Enabled"; then
        echo "Enabling pf..."
        pfctl -e 2>/dev/null || true
    fi

    echo ""
    echo "Anchor $ANCHOR_NAME enabled."
    echo "Note: Rules only apply within the anchor scope."
}

# Disable anchor
disable_anchor() {
    echo "Disabling pf anchor: $ANCHOR_NAME"

    # Flush anchor rules
    pfctl -a "$ANCHOR_NAME" -F all 2>/dev/null || true

    echo "Anchor $ANCHOR_NAME disabled (rules flushed)."
}

# Show status
show_status() {
    echo "=== pf Status ==="
    pfctl -s info 2>/dev/null | head -5
    echo ""
    echo "=== Anchor: $ANCHOR_NAME ==="
    echo "Rules:"
    pfctl -a "$ANCHOR_NAME" -s rules 2>/dev/null || echo "  (no rules loaded)"
    echo ""
    echo "Tables:"
    echo "  github_ips: $(pfctl -a "$ANCHOR_NAME" -t github_ips -T show 2>/dev/null | wc -l | xargs) entries"
    echo "  allowed_ips: $(pfctl -a "$ANCHOR_NAME" -t allowed_ips -T show 2>/dev/null | wc -l | xargs) entries"
}

# Main
case "${1:-enable}" in
    enable)
        enable_anchor
        ;;
    disable)
        disable_anchor
        ;;
    status)
        show_status
        ;;
    refresh)
        populate_tables
        ;;
    *)
        echo "Usage: sudo $0 [enable|disable|status|refresh]"
        exit 1
        ;;
esac
