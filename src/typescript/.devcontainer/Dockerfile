# TypeScript Agent Sandbox
# AI coding agents (Claude Code, Codex, Gemini CLI) with fish shell + hydro prompt

ARG NODE_VERSION=24
FROM node:${NODE_VERSION}-bookworm

ARG CLAUDE_CODE_VERSION=latest
ARG DEBIAN_FRONTEND=noninteractive

ENV DEVCONTAINER=true

# Install system dependencies
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
    # Python (for tooling/scripts)
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Disable sudo audit plugin (can fail in minimal containers)
RUN sed -i '/sudoers_audit/d' /etc/sudo.conf || true

# Install uv (fast Python package manager)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Install git-delta for better diffs
RUN ARCH=$(dpkg --print-architecture) && \
    curl -fsSL "https://github.com/dandavison/delta/releases/download/0.19.2/git-delta_0.19.2_${ARCH}.deb" \
    -o /tmp/git-delta.deb && \
    dpkg -i /tmp/git-delta.deb && \
    rm /tmp/git-delta.deb

# Create dev user with bash as default shell (fish installed for terminals)
RUN useradd -m -s /bin/bash -G sudo dev && \
    echo "dev ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/dev && \
    chmod 0440 /etc/sudoers.d/dev

# Setup npm global packages path
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH="${NPM_CONFIG_PREFIX}/bin:${PATH}"
RUN mkdir -p ${NPM_CONFIG_PREFIX} && \
    chown -R dev:dev ${NPM_CONFIG_PREFIX} && \
    npm config set fund false && \
    npm config set update-notifier false

# Install Claude Code, Codex, Gemini CLI, and common global packages
RUN npm install -g \
    @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION} \
    @openai/codex \
    @google/gemini-cli \
    typescript \
    ts-node \
    pnpm \
    eslint \
    prettier && \
    chown -R dev:dev ${NPM_CONFIG_PREFIX}

# Setup directories
RUN mkdir -p /workspace /home/dev/.claude /home/dev/.codex /home/dev/.gemini /home/dev/.cache /home/dev/.npm /home/dev/.pnpm-store && \
    chown -R dev:dev /workspace /home/dev/.claude /home/dev/.codex /home/dev/.gemini /home/dev/.cache /home/dev/.npm /home/dev/.pnpm-store

# Ensure we have root when writing to /usr/local/bin (devcontainers may switch users).
USER root

# Install Gemini extensions on first start
RUN install -m 0755 /dev/stdin /usr/local/bin/init-gemini-extensions.sh <<'EOF'
#!/bin/bash
set -e

MARKER="$HOME/.gemini/.extensions-installed"
if [ -f "$MARKER" ]; then
  exit 0
fi

mkdir -p "$HOME/.gemini"

if ! command -v gemini >/dev/null 2>&1; then
  exit 0
fi

set +e
installed_extensions="$(gemini extensions list 2>/dev/null || true)"

install_extension() {
  local url="$1"
  local repo="${url##*/}"
  local short="${repo%-extension}"
  if [ -n "$installed_extensions" ]; then
    if printf '%s\n' "$installed_extensions" | grep -Fq "$url"; then
      return 0
    fi
    if printf '%s\n' "$installed_extensions" | grep -Fq "$repo"; then
      return 0
    fi
    if [ "$short" != "$repo" ] && printf '%s\n' "$installed_extensions" | grep -Fq "$short"; then
      return 0
    fi
  fi
  gemini extensions install "$url" || echo "WARN: failed to install $url"
}

install_extension https://github.com/galz10/pickle-rick-extension
install_extension https://github.com/gemini-cli-extensions/jules
install_extension https://github.com/upstash/context7
install_extension https://github.com/exa-labs/exa-mcp-server
install_extension https://github.com/gemini-cli-extensions/security
install_extension https://github.com/gemini-cli-extensions/code-review

touch "$MARKER"
EOF

# Bypass Claude Code onboarding when CLAUDE_CODE_OAUTH_TOKEN is set.
# Workaround for anthropics/claude-code#8938.
RUN install -m 0755 /dev/stdin /usr/local/bin/init-claude-auth.sh <<'EOF'
#!/bin/bash
set -e

[ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ] && exit 0
command -v claude >/dev/null 2>&1 || exit 0

CLAUDE_JSON="$HOME/.claude.json"

if [ -f "$CLAUDE_JSON" ] && jq -e '.hasCompletedOnboarding == true' "$CLAUDE_JSON" >/dev/null 2>&1; then
  exit 0
fi

timeout 30 claude -p ok >/dev/null 2>&1 || true

if [ -f "$CLAUDE_JSON" ]; then
  tmp=$(mktemp)
  jq '.hasCompletedOnboarding = true' "$CLAUDE_JSON" > "$tmp" && mv "$tmp" "$CLAUDE_JSON"
fi
EOF

# Configure MCP servers for Claude Code and Codex
RUN install -m 0755 /dev/stdin /usr/local/bin/init-mcp.sh <<'EOF'
#!/bin/bash
set -e

if ! command -v claude >/dev/null 2>&1 && ! command -v codex >/dev/null 2>&1; then
  exit 0
fi

mkdir -p "$HOME/.claude" "$HOME/.codex"

if [ -n "${CONTEXT7_API_KEY:-}" ]; then
  if command -v claude >/dev/null 2>&1; then
    if ! claude mcp get context7 >/dev/null 2>&1; then
      claude mcp add --transport stdio --env CONTEXT7_API_KEY="$CONTEXT7_API_KEY" context7 -- npx -y @upstash/context7-mcp
    fi
  fi
  if command -v codex >/dev/null 2>&1; then
    if ! grep -q '^\[mcp_servers\.context7\]' "$HOME/.codex/config.toml" 2>/dev/null; then
      codex mcp add context7 --env CONTEXT7_API_KEY="$CONTEXT7_API_KEY" -- npx -y @upstash/context7-mcp
    fi
  fi
fi

if [ -n "${EXA_API_KEY:-}" ]; then
  if command -v claude >/dev/null 2>&1; then
    if ! claude mcp get exa >/dev/null 2>&1; then
      claude mcp add --transport stdio --env EXA_API_KEY="$EXA_API_KEY" exa -- npx -y exa-mcp-server
    fi
  fi
  if command -v codex >/dev/null 2>&1; then
    if ! grep -q '^\[mcp_servers\.exa\]' "$HOME/.codex/config.toml" 2>/dev/null; then
      codex mcp add exa --env EXA_API_KEY="$EXA_API_KEY" -- npx -y exa-mcp-server
    fi
  fi
fi
EOF

# GitHub App token helpers (least-privilege git auth)
RUN install -m 0755 /dev/stdin /usr/local/bin/github-app-token.sh <<'EOF'
#!/bin/bash
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
    echo "Error: No private key provided" >&2
    exit 1
fi

HEADER=$(printf '{"alg":"RS256","typ":"JWT"}' | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')
NOW=$(date +%s)
IAT=$((NOW - 60))
EXP=$((NOW + 600))
PAYLOAD=$(printf '{"iat":%d,"exp":%d,"iss":"%s"}' "$IAT" "$EXP" "$APP_ID" | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')
SIGNATURE=$(printf '%s.%s' "$HEADER" "$PAYLOAD" | openssl dgst -sha256 -sign <(echo "$PRIVATE_KEY") | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')
JWT="${HEADER}.${PAYLOAD}.${SIGNATURE}"

RESPONSE=$(curl -sf -X POST \
    -H "Authorization: Bearer $JWT" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/app/installations/${INSTALL_ID}/access_tokens") || {
    echo "Error: Failed to get installation token" >&2
    exit 1
}

TOKEN=$(echo "$RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
[[ -z "$TOKEN" ]] && { echo "Error: No token in API response" >&2; exit 1; }

if [[ "$CONFIGURE_GIT" == true ]]; then
    git config --global --unset-all url."https://x-access-token:${TOKEN}@github.com/".insteadOf >/dev/null 2>&1 || true
    git config --global --add url."https://x-access-token:${TOKEN}@github.com/".insteadOf "https://github.com/"
    git config --global --add url."https://x-access-token:${TOKEN}@github.com/".insteadOf "git@github.com:"
    [[ "$QUIET" != true ]] && echo "Git configured with GitHub App token"
else
    echo "$TOKEN"
fi
EOF

RUN install -m 0755 /dev/stdin /usr/local/bin/init-github-app.sh <<'EOF'
#!/bin/bash
set -euo pipefail

[[ -z "${GITHUB_APP_ID:-}" ]] && exit 0
[[ -z "${GITHUB_APP_INSTALL_ID:-}" ]] && exit 0
[[ -z "${GITHUB_APP_KEY_BASE64:-}" && -z "${GITHUB_APP_KEY_PATH:-}" ]] && exit 0

/usr/local/bin/github-app-token.sh --configure-git --quiet
echo "GitHub App authentication configured"
EOF

# Switch to dev user
USER dev
WORKDIR /home/dev

# Setup fish with fisher and hydro
RUN mkdir -p ~/.config/fish/functions ~/.config/fish/conf.d

# Install fisher (fish plugin manager)
RUN curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish \
    -o ~/.config/fish/functions/fisher.fish

# Configure fish
COPY --chown=dev:dev config.fish /home/dev/.config/fish/config.fish

# Install hydro prompt via fisher
RUN fish -c "fisher install jorgebucaran/hydro" && \
    fish -c "fisher install PatrickF1/fzf.fish"

# Default shell and editor
ENV SHELL=/bin/bash
ENV EDITOR=nano
ENV VISUAL=nano

WORKDIR /workspace
