# Python Agent Sandbox
# AI coding agents (Claude Code, Codex, Gemini CLI) with fish shell + hydro prompt

ARG NODE_VERSION=24
ARG PYTHON_VERSION=3.14
FROM python:${PYTHON_VERSION}-bookworm

ARG NODE_VERSION
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
    libffi-dev \
    && rm -rf /var/lib/apt/lists/*

# Disable sudo audit plugin (can fail in minimal containers)
RUN sed -i '/sudoers_audit/d' /etc/sudo.conf || true

# Install Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# Install git-delta for better diffs
RUN ARCH=$(dpkg --print-architecture) && \
    curl -fsSL "https://github.com/dandavison/delta/releases/download/0.18.2/git-delta_0.18.2_${ARCH}.deb" \
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

# Install Claude Code, Codex, and Gemini CLI
RUN npm install -g \
    @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION} \
    @openai/codex \
    @google/gemini-cli

# Setup directories
RUN mkdir -p /workspace /home/dev/.claude /home/dev/.codex /home/dev/.gemini /home/dev/.cache/uv && \
    chown -R dev:dev /workspace /home/dev/.claude /home/dev/.codex /home/dev/.gemini /home/dev/.cache/uv

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

# Switch to dev user
USER dev
WORKDIR /home/dev

# Install uv (fast Python package manager)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/home/dev/.local/bin:${PATH}"

# Install common Python tools via uv
RUN /home/dev/.local/bin/uv tool install ruff && \
    /home/dev/.local/bin/uv tool install mypy && \
    /home/dev/.local/bin/uv tool install pytest

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
