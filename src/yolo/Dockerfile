# =============================================================================
# Yolo Mode - Universal AI Agent Container
# =============================================================================
# All languages (Rust, Python, Go, TypeScript) with embedded firewall.
# For running Claude Code, Codex, Gemini CLI in fully autonomous mode.
#
# Usage:
#   docker build -t yolo .
#   docker run -it --rm --cap-add=NET_ADMIN -v $(pwd):/workspace yolo claude
# =============================================================================

ARG NODE_VERSION=22
FROM node:${NODE_VERSION}-bookworm

ARG RUST_VERSION=stable
ARG GO_VERSION=1.24.4
ARG PYTHON_VERSION=3.13
ARG CLAUDE_CODE_VERSION=latest
ARG DEBIAN_FRONTEND=noninteractive

ENV DEVCONTAINER=true

# =============================================================================
# System Dependencies + Firewall Tools
# =============================================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Development essentials
    git \
    less \
    procps \
    sudo \
    fzf \
    fish \
    man-db \
    unzip \
    gnupg2 \
    gh \
    curl \
    wget \
    # Editors
    nano \
    vim \
    # Utilities
    jq \
    ripgrep \
    fd-find \
    tree \
    htop \
    # Build tools
    build-essential \
    pkg-config \
    libssl-dev \
    ca-certificates \
    cmake \
    # Firewall tools
    iptables \
    ipset \
    iproute2 \
    dnsutils \
    aggregate \
    # Python build deps
    libffi-dev \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    libncurses5-dev \
    libncursesw5-dev \
    xz-utils \
    tk-dev \
    liblzma-dev \
    && ln -sf /usr/bin/fdfind /usr/local/bin/fd \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# LLVM 21 Toolchain (for Rust llvm-sys)
# =============================================================================
RUN wget -qO- https://apt.llvm.org/llvm-snapshot.gpg.key \
    | tee /etc/apt/trusted.gpg.d/apt.llvm.org.asc >/dev/null \
    && echo "deb http://apt.llvm.org/bookworm/ llvm-toolchain-bookworm-21 main" \
    > /etc/apt/sources.list.d/llvm.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    llvm-21 \
    llvm-21-dev \
    clang-21 \
    lld-21 \
    libclang-21-dev \
    mold \
    && rm -rf /var/lib/apt/lists/*

# Disable sudo audit plugin (can fail in minimal containers)
RUN sed -i '/sudoers_audit/d' /etc/sudo.conf || true

# =============================================================================
# Go Installation
# =============================================================================
RUN ARCH=$(dpkg --print-architecture) && \
    case "$ARCH" in \
        amd64) GOARCH="amd64" ;; \
        arm64) GOARCH="arm64" ;; \
        *) echo "Unsupported arch: $ARCH" && exit 1 ;; \
    esac && \
    curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${GOARCH}.tar.gz" | tar -C /usr/local -xz

ENV PATH="/usr/local/go/bin:${PATH}"
ENV GOPATH="/home/dev/go"

# Install common Go tools (GOBIN ensures they go to /usr/local/bin directly)
RUN GOBIN=/usr/local/bin go install golang.org/x/tools/gopls@latest && \
    GOBIN=/usr/local/bin go install github.com/go-delve/delve/cmd/dlv@latest && \
    GOBIN=/usr/local/bin go install honnef.co/go/tools/cmd/staticcheck@latest

# =============================================================================
# Python (via uv)
# =============================================================================
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

# Install Python and common tools via uv
RUN /root/.local/bin/uv python install ${PYTHON_VERSION} && \
    /root/.local/bin/uv tool install ruff && \
    /root/.local/bin/uv tool install mypy

# =============================================================================
# Git Delta (better diffs)
# =============================================================================
RUN ARCH=$(dpkg --print-architecture) && \
    curl -fsSL "https://github.com/dandavison/delta/releases/download/0.18.2/git-delta_0.18.2_${ARCH}.deb" \
    -o /tmp/git-delta.deb && \
    dpkg -i /tmp/git-delta.deb && \
    rm /tmp/git-delta.deb

# =============================================================================
# Create dev user
# =============================================================================
RUN useradd -m -s /bin/bash -G sudo dev && \
    echo "dev ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/dev && \
    chmod 0440 /etc/sudoers.d/dev

# =============================================================================
# npm global packages + AI Agents
# =============================================================================
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH="${NPM_CONFIG_PREFIX}/bin:${PATH}"

RUN mkdir -p ${NPM_CONFIG_PREFIX} && \
    chown -R dev:dev ${NPM_CONFIG_PREFIX} && \
    npm config set fund false && \
    npm config set update-notifier false

# Install AI agents + TypeScript tooling
RUN npm install -g \
    @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION} \
    @openai/codex \
    @google/gemini-cli \
    typescript \
    tsx \
    @biomejs/biome

# =============================================================================
# Setup directories
# =============================================================================
RUN mkdir -p /workspace \
    /home/dev/.claude \
    /home/dev/.codex \
    /home/dev/.gemini \
    /home/dev/.cache/sccache \
    /home/dev/go && \
    chown -R dev:dev /workspace /home/dev

# =============================================================================
# Embedded Firewall Script
# =============================================================================
COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

# Allow passwordless sudo for firewall init
RUN echo "dev ALL=(root) NOPASSWD: /usr/local/bin/init-firewall" >> /etc/sudoers.d/dev

# Embed firewall init script (extracted from features/firewall)
RUN install -m 0755 /dev/stdin /usr/local/bin/init-firewall <<'FIREWALL_EOF'
#!/bin/bash
set -e

if [ "${FIREWALL_ENABLED:-true}" != "true" ]; then
    echo "Firewall disabled"
    exit 0
fi

if ! iptables -L &>/dev/null; then
    echo "Warning: iptables not available (no NET_ADMIN capability)"
    exit 0
fi

# Read options from environment
ALLOW_GITHUB="${ALLOWGITHUB:-true}"
ALLOW_NPM="${ALLOWNPM:-true}"
ALLOW_PYPI="${ALLOWPYPI:-true}"
ALLOW_CRATES="${ALLOWCRATES:-true}"
ALLOW_GO="${ALLOWGO:-true}"
ALLOW_ANTHROPIC="${ALLOWANTHROPIC:-true}"
ALLOW_OPENAI="${ALLOWOPENAI:-true}"
ALLOW_GOOGLE="${ALLOWGOOGLE:-true}"
ALLOW_DEBIAN="${ALLOWDEBIAN:-true}"
CUSTOM_DOMAINS="${CUSTOMDOMAINS:-}"

echo "Initializing firewall..."

# Preserve Docker DNS rules
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

add_cidr() {
    local cidr="$1"
    if [[ "$cidr" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?$ ]]; then
        ipset add allowed-domains "$cidr" 2>/dev/null || true
    fi
}

add_domain() {
    local domain="$1"
    local ips=$(dig +short "$domain" A 2>/dev/null | grep -E '^[0-9]+\.' || true)
    for ip in $ips; do
        add_cidr "$ip/32"
    done
}

# GitHub
if [ "$ALLOW_GITHUB" = "true" ]; then
    echo "  + GitHub"
    GITHUB_META=$(curl -sf https://api.github.com/meta 2>/dev/null || echo '{}')
    for key in hooks git packages pages importer actions dependabot copilot; do
        echo "$GITHUB_META" | jq -r ".${key}[]? // empty" 2>/dev/null | while read -r cidr; do
            add_cidr "$cidr"
        done
    done
    for d in github.com api.github.com raw.githubusercontent.com ghcr.io \
             pkg-containers.githubusercontent.com objects.githubusercontent.com; do
        add_domain "$d"
    done
fi

# Debian/Ubuntu
if [ "$ALLOW_DEBIAN" = "true" ]; then
    echo "  + Debian/Ubuntu repos"
    for d in deb.debian.org security.debian.org archive.ubuntu.com security.ubuntu.com; do
        add_domain "$d"
    done
fi

# npm
if [ "$ALLOW_NPM" = "true" ]; then
    echo "  + npm registry"
    for d in registry.npmjs.org registry.yarnpkg.com; do
        add_domain "$d"
    done
fi

# PyPI
if [ "$ALLOW_PYPI" = "true" ]; then
    echo "  + PyPI"
    for d in pypi.org files.pythonhosted.org pypi.python.org; do
        add_domain "$d"
    done
fi

# crates.io
if [ "$ALLOW_CRATES" = "true" ]; then
    echo "  + crates.io"
    for d in crates.io static.crates.io index.crates.io static.rust-lang.org; do
        add_domain "$d"
    done
fi

# Go
if [ "$ALLOW_GO" = "true" ]; then
    echo "  + Go proxy"
    for d in proxy.golang.org sum.golang.org storage.googleapis.com; do
        add_domain "$d"
    done
fi

# Anthropic
if [ "$ALLOW_ANTHROPIC" = "true" ]; then
    echo "  + Anthropic API"
    for d in api.anthropic.com claude.ai console.anthropic.com statsig.anthropic.com; do
        add_domain "$d"
    done
fi

# OpenAI
if [ "$ALLOW_OPENAI" = "true" ]; then
    echo "  + OpenAI API"
    for d in api.openai.com platform.openai.com chat.openai.com chatgpt.com \
             openai.com auth.openai.com setup.auth.openai.com auth0.openai.com; do
        add_domain "$d"
    done
fi

# Google AI
if [ "$ALLOW_GOOGLE" = "true" ]; then
    echo "  + Google AI"
    for d in generativelanguage.googleapis.com aiplatform.googleapis.com \
             aistudio.google.com accounts.google.com oauth2.googleapis.com; do
        add_domain "$d"
    done
fi

# Always allowed
for d in sentry.io context7.com mcp.context7.com astral.sh; do
    add_domain "$d"
done

# Custom domains
if [ -n "$CUSTOM_DOMAINS" ]; then
    echo "  + Custom domains"
    IFS=',' read -ra DOMAINS <<< "$CUSTOM_DOMAINS"
    for domain in "${DOMAINS[@]}"; do
        domain=$(echo "$domain" | xargs)
        [ -n "$domain" ] && add_domain "$domain"
    done
fi

# Allow private networks
for cidr in 127.0.0.0/8 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16; do
    add_cidr "$cidr"
done

# Host network
HOST_NETWORK=$(ip route | grep default | awk '{print $3}' | head -1)
if [ -n "$HOST_NETWORK" ]; then
    HOST_CIDR=$(echo "$HOST_NETWORK" | sed 's/\.[0-9]*$/.0\/24/')
    add_cidr "$HOST_CIDR"
fi

# Apply iptables rules
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow DNS, SSH, HTTP, HTTPS, git to allowed domains
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 22 -m set --match-set allowed-domains dst -j ACCEPT
iptables -A OUTPUT -p tcp --dport 80 -m set --match-set allowed-domains dst -j ACCEPT
iptables -A OUTPUT -p tcp --dport 443 -m set --match-set allowed-domains dst -j ACCEPT
iptables -A OUTPUT -p tcp --dport 9418 -m set --match-set allowed-domains dst -j ACCEPT

echo "Firewall initialized (default-deny + allowlist)"
FIREWALL_EOF

# =============================================================================
# Install Gemini Extensions Script
# =============================================================================
RUN install -m 0755 /dev/stdin /usr/local/bin/init-gemini-extensions.sh <<'EOF'
#!/bin/bash
set -e

MARKER="$HOME/.gemini/.extensions-installed"
[ -f "$MARKER" ] && exit 0

mkdir -p "$HOME/.gemini"
command -v gemini >/dev/null 2>&1 || exit 0

set +e
installed_extensions="$(gemini extensions list 2>/dev/null || true)"

install_extension() {
    local url="$1"
    local repo="${url##*/}"
    local short="${repo%-extension}"
    if [ -n "$installed_extensions" ]; then
        printf '%s\n' "$installed_extensions" | grep -Fq "$url" && return 0
        printf '%s\n' "$installed_extensions" | grep -Fq "$repo" && return 0
        [ "$short" != "$repo" ] && printf '%s\n' "$installed_extensions" | grep -Fq "$short" && return 0
    fi
    gemini extensions install "$url" || echo "WARN: failed to install $url"
}

install_extension https://github.com/upstash/context7
install_extension https://github.com/exa-labs/exa-mcp-server

touch "$MARKER"
EOF

# =============================================================================
# Configure MCP Servers Script
# =============================================================================
RUN install -m 0755 /dev/stdin /usr/local/bin/init-mcp.sh <<'EOF'
#!/bin/bash
set -e

command -v claude >/dev/null 2>&1 || command -v codex >/dev/null 2>&1 || exit 0

mkdir -p "$HOME/.claude" "$HOME/.codex"

if [ -n "${CONTEXT7_API_KEY:-}" ]; then
    if command -v claude >/dev/null 2>&1; then
        claude mcp get context7 >/dev/null 2>&1 || \
            claude mcp add --transport stdio --env CONTEXT7_API_KEY="$CONTEXT7_API_KEY" context7 -- npx -y @upstash/context7-mcp
    fi
    if command -v codex >/dev/null 2>&1; then
        grep -q '^\[mcp_servers\.context7\]' "$HOME/.codex/config.toml" 2>/dev/null || \
            codex mcp add context7 --env CONTEXT7_API_KEY="$CONTEXT7_API_KEY" -- npx -y @upstash/context7-mcp
    fi
fi

if [ -n "${EXA_API_KEY:-}" ]; then
    if command -v claude >/dev/null 2>&1; then
        claude mcp get exa >/dev/null 2>&1 || \
            claude mcp add --transport stdio --env EXA_API_KEY="$EXA_API_KEY" exa -- npx -y exa-mcp-server
    fi
    if command -v codex >/dev/null 2>&1; then
        grep -q '^\[mcp_servers\.exa\]' "$HOME/.codex/config.toml" 2>/dev/null || \
            codex mcp add exa --env EXA_API_KEY="$EXA_API_KEY" -- npx -y exa-mcp-server
    fi
fi
EOF

# =============================================================================
# GitHub App Token Scripts
# =============================================================================
RUN install -m 0755 /dev/stdin /usr/local/bin/github-app-token.sh <<'GHAPP_EOF'
#!/bin/bash
# Generate GitHub App installation access token
set -euo pipefail

APP_ID="${GITHUB_APP_ID:-}"
INSTALL_ID="${GITHUB_APP_INSTALL_ID:-}"
KEY_PATH="${GITHUB_APP_KEY_PATH:-}"
KEY_BASE64="${GITHUB_APP_KEY_BASE64:-}"
CONFIGURE_GIT=false
QUIET=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --app-id) APP_ID="$2"; shift 2 ;;
        --install-id) INSTALL_ID="$2"; shift 2 ;;
        --key) KEY_PATH="$2"; shift 2 ;;
        --key-base64) KEY_BASE64="$2"; shift 2 ;;
        --configure-git) CONFIGURE_GIT=true; shift ;;
        --quiet|-q) QUIET=true; shift ;;
        *) shift ;;
    esac
done

[[ -z "$APP_ID" ]] && { echo "Error: GITHUB_APP_ID required" >&2; exit 1; }
[[ -z "$INSTALL_ID" ]] && { echo "Error: GITHUB_APP_INSTALL_ID required" >&2; exit 1; }

if [[ -n "$KEY_BASE64" ]]; then
    PRIVATE_KEY=$(echo "$KEY_BASE64" | base64 -d)
elif [[ -f "$KEY_PATH" ]]; then
    PRIVATE_KEY=$(cat "$KEY_PATH")
else
    echo "Error: No private key provided" >&2; exit 1
fi

# Generate JWT
HEADER=$(printf '{"alg":"RS256","typ":"JWT"}' | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')
NOW=$(date +%s); IAT=$((NOW - 60)); EXP=$((NOW + 600))
PAYLOAD=$(printf '{"iat":%d,"exp":%d,"iss":"%s"}' "$IAT" "$EXP" "$APP_ID" | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')
SIGNATURE=$(printf '%s.%s' "$HEADER" "$PAYLOAD" | openssl dgst -sha256 -sign <(echo "$PRIVATE_KEY") | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')
JWT="${HEADER}.${PAYLOAD}.${SIGNATURE}"

# Get installation token
RESPONSE=$(curl -sf -X POST \
    -H "Authorization: Bearer $JWT" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/app/installations/${INSTALL_ID}/access_tokens") || { echo "Error: API failed" >&2; exit 1; }

TOKEN=$(echo "$RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
[[ -z "$TOKEN" ]] && { echo "Error: No token" >&2; exit 1; }

if [[ "$CONFIGURE_GIT" == true ]]; then
    git config --global --unset-all url."https://x-access-token:${TOKEN}@github.com/".insteadOf >/dev/null 2>&1 || true
    git config --global --add url."https://x-access-token:${TOKEN}@github.com/".insteadOf "https://github.com/"
    git config --global --add url."https://x-access-token:${TOKEN}@github.com/".insteadOf "git@github.com:"
    [[ "$QUIET" != true ]] && echo "Git configured with GitHub App token"
else
    echo "$TOKEN"
fi
GHAPP_EOF

RUN install -m 0755 /dev/stdin /usr/local/bin/init-github-app.sh <<'GHAPP_INIT_EOF'
#!/bin/bash
# Initialize GitHub App token in devcontainer (silent skip if not configured)
set -euo pipefail
[[ -z "${GITHUB_APP_ID:-}" ]] && exit 0
[[ -z "${GITHUB_APP_INSTALL_ID:-}" ]] && exit 0
[[ -z "${GITHUB_APP_KEY_BASE64:-}" && -z "${GITHUB_APP_KEY_PATH:-}" ]] && exit 0
echo "Configuring git with GitHub App token..."
/usr/local/bin/github-app-token.sh --configure-git --quiet
echo "GitHub App authentication configured"
GHAPP_INIT_EOF

# =============================================================================
# Switch to dev user for Rust installation
# =============================================================================
USER dev
WORKDIR /home/dev

# Install Rust toolchain
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
    sh -s -- -y --default-toolchain ${RUST_VERSION} --profile default

ENV PATH="/home/dev/.cargo/bin:${PATH}"
ENV CARGO_HOME=/home/dev/.cargo
ENV RUSTUP_HOME=/home/dev/.rustup
ENV LLVM_SYS_211_PREFIX=/usr/lib/llvm-21

# Install common Rust tools
RUN cargo install --locked \
    cargo-watch \
    cargo-edit \
    cargo-expand \
    cargo-outdated \
    sccache

ENV RUSTC_WRAPPER=sccache

# =============================================================================
# Fish Shell + Hydro Prompt
# =============================================================================
RUN mkdir -p ~/.config/fish/functions ~/.config/fish/conf.d

# Install fisher
RUN curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish \
    -o ~/.config/fish/functions/fisher.fish

# Configure fish
RUN cat > ~/.config/fish/config.fish << 'FISHEOF'
# Yolo Mode Fish Config
if status is-interactive
    # Hydro prompt
    set -g hydro_symbol_prompt ">"
    set -g hydro_color_prompt green

    # Aliases
    alias ll="ls -la"
    alias g="git"

    # Path additions
    fish_add_path ~/.cargo/bin
    fish_add_path ~/go/bin
    fish_add_path ~/.local/bin
end
FISHEOF

# Install hydro and fzf plugins
RUN fish -c "fisher install jorgebucaran/hydro" && \
    fish -c "fisher install PatrickF1/fzf.fish"

# Move uv to dev user
USER root
RUN mv /root/.local /home/dev/.local && \
    chown -R dev:dev /home/dev/.local
USER dev

ENV PATH="/home/dev/.local/bin:${PATH}"
ENV SHELL=/bin/bash
ENV EDITOR=nano
ENV VISUAL=nano

WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash"]
