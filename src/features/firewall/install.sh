#!/bin/bash
# =============================================================================
# Network Firewall Feature - install.sh
# =============================================================================
# Installs firewall dependencies and sets up the init script.
# The actual firewall rules are applied at container start via postStartCommand.
# =============================================================================

set -e

echo "Installing Network Firewall Feature..."

# Install required packages
apt-get update
apt-get install -y --no-install-recommends \
    iptables \
    ipset \
    iproute2 \
    dnsutils \
    aggregate \
    jq \
    curl

rm -rf /var/lib/apt/lists/*

# Persist feature options for runtime (postStartCommand)
cat > /etc/firewall.env << EOF
ALLOWGITHUB_DEFAULT="${ALLOWGITHUB:-true}"
ALLOWNPM_DEFAULT="${ALLOWNPM:-true}"
ALLOWPYPI_DEFAULT="${ALLOWPYPI:-true}"
ALLOWCRATES_DEFAULT="${ALLOWCRATES:-true}"
ALLOWGO_DEFAULT="${ALLOWGO:-true}"
ALLOWANTHROPIC_DEFAULT="${ALLOWANTHROPIC:-true}"
ALLOWOPENAI_DEFAULT="${ALLOWOPENAI:-true}"
ALLOWGOOGLE_DEFAULT="${ALLOWGOOGLE:-true}"
ALLOWVSCODE_DEFAULT="${ALLOWVSCODE:-true}"
ALLOWZED_DEFAULT="${ALLOWZED:-true}"
ALLOWDEBIAN_DEFAULT="${ALLOWDEBIAN:-true}"
CUSTOMDOMAINS_DEFAULT="${CUSTOMDOMAINS:-}"
EOF

# Create the firewall init script
cat > /usr/local/bin/init-firewall.sh << 'FIREWALL_SCRIPT'
#!/bin/bash
# =============================================================================
# init-firewall.sh - Network firewall for AI coding agent sandbox
# =============================================================================
# Implements default-deny with allowlist for necessary services.
# =============================================================================

set -e

echo "Initializing firewall..."

# Allow devcontainer templates to disable firewall at runtime.
if [ "${FIREWALL_ENABLED:-true}" != "true" ]; then
    echo "Firewall disabled (FIREWALL_ENABLED=$FIREWALL_ENABLED)"
    exit 0
fi

# Check if we have the required capabilities
if ! iptables -L &>/dev/null; then
    echo "Warning: iptables not available or no NET_ADMIN capability"
    echo "Firewall not configured - running without network restrictions"
    exit 0
fi

# Load persisted feature defaults, then apply runtime overrides.
if [ -f /etc/firewall.env ]; then
    # shellcheck disable=SC1091
    . /etc/firewall.env
fi

# Read feature options from environment
ALLOW_GITHUB="${ALLOWGITHUB:-${ALLOWGITHUB_DEFAULT:-true}}"
ALLOW_NPM="${ALLOWNPM:-${ALLOWNPM_DEFAULT:-true}}"
ALLOW_PYPI="${ALLOWPYPI:-${ALLOWPYPI_DEFAULT:-true}}"
ALLOW_CRATES="${ALLOWCRATES:-${ALLOWCRATES_DEFAULT:-true}}"
ALLOW_GO="${ALLOWGO:-${ALLOWGO_DEFAULT:-true}}"
ALLOW_ANTHROPIC="${ALLOWANTHROPIC:-${ALLOWANTHROPIC_DEFAULT:-true}}"
ALLOW_OPENAI="${ALLOWOPENAI:-${ALLOWOPENAI_DEFAULT:-true}}"
ALLOW_GOOGLE="${ALLOWGOOGLE:-${ALLOWGOOGLE_DEFAULT:-true}}"
ALLOW_VSCODE="${ALLOWVSCODE:-${ALLOWVSCODE_DEFAULT:-true}}"
ALLOW_ZED="${ALLOWZED:-${ALLOWZED_DEFAULT:-true}}"
ALLOW_DEBIAN="${ALLOWDEBIAN:-${ALLOWDEBIAN_DEFAULT:-true}}"
CUSTOM_DOMAINS="${CUSTOMDOMAINS:-${CUSTOMDOMAINS_DEFAULT:-}}"

# Preserve Docker DNS rules before flushing
DOCKER_DNS_RULES=$(iptables -t nat -S 2>/dev/null | grep -E "DOCKER|docker" || true)

# Flush existing rules
iptables -F
iptables -X 2>/dev/null || true
iptables -t nat -F
iptables -t nat -X 2>/dev/null || true

# Restore Docker DNS rules
if [ -n "$DOCKER_DNS_RULES" ]; then
    echo "$DOCKER_DNS_RULES" | while read -r rule; do
        iptables -t nat ${rule:2} 2>/dev/null || true
    done
fi

# Create ipset for allowed domains
ipset destroy allowed-domains 2>/dev/null || true
ipset create allowed-domains hash:net

# Function to add CIDR to ipset
add_cidr() {
    local cidr="$1"
    if [[ "$cidr" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?$ ]]; then
        ipset add allowed-domains "$cidr" 2>/dev/null || true
    fi
}

# Function to resolve domain and add IPs
add_domain() {
    local domain="$1"
    echo "  Resolving: $domain"
    local ips=$(dig +short "$domain" A 2>/dev/null | grep -E '^[0-9]+\.' || true)
    for ip in $ips; do
        add_cidr "$ip/32"
    done
}

# GitHub
if [ "$ALLOW_GITHUB" = "true" ]; then
    echo "Adding GitHub IP ranges..."
    GITHUB_META=$(curl -sf https://api.github.com/meta 2>/dev/null || echo '{}')
    for key in hooks git packages pages importer actions dependabot copilot; do
        echo "$GITHUB_META" | jq -r ".${key}[]? // empty" 2>/dev/null | while read -r cidr; do
            add_cidr "$cidr"
        done
    done
    add_domain "github.com"
    add_domain "api.github.com"
    add_domain "raw.githubusercontent.com"
    add_domain "github.githubassets.com"
    add_domain "collector.github.com"
    add_domain "ghcr.io"
    add_domain "pkg-containers.githubusercontent.com"
    add_domain "objects.githubusercontent.com"
fi

# Debian/Ubuntu packages
if [ "$ALLOW_DEBIAN" = "true" ]; then
    echo "Adding Debian/Ubuntu repos..."
    add_domain "deb.debian.org"
    add_domain "security.debian.org"
    add_domain "archive.ubuntu.com"
    add_domain "security.ubuntu.com"
fi

# npm registry
if [ "$ALLOW_NPM" = "true" ]; then
    echo "Adding npm registry..."
    add_domain "registry.npmjs.org"
    add_domain "registry.yarnpkg.com"
fi

# PyPI (Python packages)
if [ "$ALLOW_PYPI" = "true" ]; then
    echo "Adding PyPI..."
    add_domain "pypi.org"
    add_domain "files.pythonhosted.org"
    add_domain "pypi.python.org"
fi

# crates.io (Rust packages)
if [ "$ALLOW_CRATES" = "true" ]; then
    echo "Adding crates.io..."
    add_domain "crates.io"
    add_domain "static.crates.io"
    add_domain "index.crates.io"
    add_domain "static.rust-lang.org"
fi

# Go modules
if [ "$ALLOW_GO" = "true" ]; then
    echo "Adding Go proxy..."
    add_domain "proxy.golang.org"
    add_domain "sum.golang.org"
    add_domain "storage.googleapis.com"
fi

# Anthropic
if [ "$ALLOW_ANTHROPIC" = "true" ]; then
    echo "Adding Anthropic API..."
    add_domain "api.anthropic.com"
    add_domain "claude.ai"
    add_domain "console.anthropic.com"
    add_domain "statsig.anthropic.com"
fi

# OpenAI
if [ "$ALLOW_OPENAI" = "true" ]; then
    echo "Adding OpenAI API..."
    add_domain "api.openai.com"
    add_domain "platform.openai.com"
    add_domain "chat.openai.com"
fi

# Google AI
if [ "$ALLOW_GOOGLE" = "true" ]; then
    echo "Adding Google AI API..."
    add_domain "generativelanguage.googleapis.com"
    add_domain "aiplatform.googleapis.com"
    add_domain "aistudio.google.com"
    add_domain "accounts.google.com"
    add_domain "oauth2.googleapis.com"
fi

# VS Code services
if [ "$ALLOW_VSCODE" = "true" ]; then
    echo "Adding VS Code services..."
    add_domain "update.code.visualstudio.com"
    add_domain "marketplace.visualstudio.com"
    add_domain "vscode.download.prss.microsoft.com"
    add_domain "az764295.vo.msecnd.net"
    add_domain "vscode.blob.core.windows.net"
fi

# Zed services (remote server downloads)
if [ "$ALLOW_ZED" = "true" ]; then
    echo "Adding Zed services..."
    add_domain "zed.dev"
fi

# Sentry (always allowed for error reporting)
add_domain "sentry.io"
add_domain "o4509242995736576.ingest.us.sentry.io"

# Context7 MCP (always allowed)
add_domain "context7.com"
add_domain "mcp.context7.com"

# Astral (uv, ruff - always allowed)
add_domain "astral.sh"

# Custom domains
if [ -n "$CUSTOM_DOMAINS" ]; then
    echo "Adding custom domains..."
    IFS=',' read -ra DOMAINS <<< "$CUSTOM_DOMAINS"
    for domain in "${DOMAINS[@]}"; do
        domain=$(echo "$domain" | xargs)  # trim whitespace
        if [ -n "$domain" ]; then
            add_domain "$domain"
        fi
    done
fi

# Detect host network for internal traffic
HOST_NETWORK=$(ip route | grep default | awk '{print $3}' | head -1)
if [ -n "$HOST_NETWORK" ]; then
    HOST_CIDR=$(echo "$HOST_NETWORK" | sed 's/\.[0-9]*$/.0\/24/')
    add_cidr "$HOST_CIDR"
fi

# Allow localhost
add_cidr "127.0.0.0/8"

# Allow private networks (for Docker networking)
add_cidr "10.0.0.0/8"
add_cidr "172.16.0.0/12"
add_cidr "192.168.0.0/16"

echo "Configuring iptables rules..."

# Set default policies to DROP
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Allow established connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow DNS (UDP and TCP)
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

# Allow SSH outbound only to allowed domains
iptables -A OUTPUT -p tcp --dport 22 -m set --match-set allowed-domains dst -j ACCEPT

# Allow HTTPS to allowed domains
iptables -A OUTPUT -p tcp --dport 443 -m set --match-set allowed-domains dst -j ACCEPT

# Allow HTTP to allowed domains (for redirects)
iptables -A OUTPUT -p tcp --dport 80 -m set --match-set allowed-domains dst -j ACCEPT

# Allow git protocol
iptables -A OUTPUT -p tcp --dport 9418 -m set --match-set allowed-domains dst -j ACCEPT

echo "Verifying firewall..."

# Test that blocked domains fail
if curl -sf --connect-timeout 2 https://example.com &>/dev/null; then
    echo "WARNING: Firewall may not be blocking correctly (example.com accessible)"
else
    echo "  [OK] Blocked domains are inaccessible"
fi

# Test that GitHub works (if enabled)
if [ "$ALLOW_GITHUB" = "true" ]; then
    if curl -sf --connect-timeout 5 https://api.github.com &>/dev/null; then
        echo "  [OK] GitHub API is accessible"
    else
        echo "  [?] GitHub API check inconclusive"
    fi
fi

echo ""
echo "========================================================================"
echo "Firewall initialized successfully!"
echo "========================================================================"
echo ""
echo "Allowed services:"
[ "$ALLOW_ANTHROPIC" = "true" ] && echo "  - Anthropic API (claude.ai, api.anthropic.com)"
[ "$ALLOW_OPENAI" = "true" ] && echo "  - OpenAI API (api.openai.com)"
[ "$ALLOW_GOOGLE" = "true" ] && echo "  - Google AI + Gemini auth (generativelanguage.googleapis.com)"
[ "$ALLOW_GITHUB" = "true" ] && echo "  - GitHub (git, API, packages, ghcr.io)"
[ "$ALLOW_NPM" = "true" ] && echo "  - npm registry"
[ "$ALLOW_PYPI" = "true" ] && echo "  - PyPI (Python packages)"
[ "$ALLOW_CRATES" = "true" ] && echo "  - crates.io (Rust packages)"
[ "$ALLOW_GO" = "true" ] && echo "  - proxy.golang.org (Go modules)"
[ "$ALLOW_VSCODE" = "true" ] && echo "  - VS Code marketplace"
[ "$ALLOW_ZED" = "true" ] && echo "  - Zed (zed.dev)"
[ "$ALLOW_DEBIAN" = "true" ] && echo "  - Debian/Ubuntu package repos"
echo "  - Sentry (error reporting)"
echo "  - Context7 MCP"
[ -n "$CUSTOM_DOMAINS" ] && echo "  - Custom: $CUSTOM_DOMAINS"
echo ""
echo "All other outbound connections are BLOCKED."
echo ""
FIREWALL_SCRIPT

chmod +x /usr/local/bin/init-firewall.sh

# Allow passwordless sudo for the firewall script
# This will be configured for the actual user by the template
echo "# Firewall feature - allow any user to run init-firewall.sh" > /etc/sudoers.d/firewall
echo "ALL ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" >> /etc/sudoers.d/firewall
chmod 0440 /etc/sudoers.d/firewall

echo "Network Firewall Feature installed successfully!"
echo "Run 'sudo /usr/local/bin/init-firewall.sh' to activate the firewall."
