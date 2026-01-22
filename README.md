# Agent Containers

Dev Container templates and features for AI coding agents (Claude Code, Codex, Gemini CLI) with optional network firewall sandbox.

## Templates

Pre-configured development environments with:
- Fish shell + [Hydro](https://github.com/jorgebucaran/hydro) prompt
- Claude Code CLI pre-installed
- Codex CLI pre-installed
- Gemini CLI pre-installed (extensions: pickle-rick-extension, jules, context7, exa-mcp-server, security, code-review)
- Common dev tools (git, gh, ripgrep, fzf, jq, delta)
- Optional network firewall (allowlist-only)

| Template | Base | Language Tools |
|----------|------|----------------|
| **rust** | Node + Rust | rustup, cargo, clippy, rustfmt, cargo-watch |
| **python** | Python 3.14 | uv, ruff, mypy, pytest |
| **go** | Go 1.25 | gopls, dlv, golangci-lint, staticcheck |
| **typescript** | Node 24 | TypeScript, pnpm, eslint, prettier |

## Quick Start

### Using a Template

```bash
# Apply a template to your project
devcontainer templates apply -t ghcr.io/blacktop/agent-containers/rust

# Or reference in your devcontainer.json
{
  "image": "ghcr.io/blacktop/agent-containers/rust:latest"
}
```

### VS Code / Codespaces

1. Open Command Palette (`Cmd+Shift+P`)
2. Select "Dev Containers: Add Dev Container Configuration Files..."
3. Search for "blacktop" or the language name
4. Select your template

## Features

### Network Firewall

A standalone feature that adds a default-deny firewall with allowlist for common development services.

```json
{
  "features": {
    "ghcr.io/blacktop/agent-containers/firewall:1": {}
  }
}
```

**Allowed by default:**
- GitHub (git, API, packages, ghcr.io)
- npm registry
- PyPI (Python packages)
- crates.io (Rust packages)
- proxy.golang.org (Go modules)
- Anthropic API (Claude)
- OpenAI API
- Google AI API
- VS Code services
- Debian/Ubuntu repos
- Sentry (error reporting)

**Configuration options:**

```json
{
  "features": {
    "ghcr.io/blacktop/agent-containers/firewall:1": {
      "allowGithub": true,
      "allowNpm": true,
      "allowPypi": true,
      "allowCrates": true,
      "allowGo": true,
      "allowAnthropic": true,
      "allowOpenai": true,
      "allowGoogle": true,
      "allowVscode": true,
      "allowDebian": true,
      "customDomains": "example.com,api.example.org"
    }
  }
}
```

## Template Options

### Rust

```json
{
  "templateOptions": {
    "rustVersion": "stable",      // stable, nightly
    "nodeVersion": "24",          // 20, 22, 24
    "claudeCodeVersion": "latest"
  }
}
```

### Python

```json
{
  "templateOptions": {
    "pythonVersion": "3.14",      // 3.11, 3.12, 3.13, 3.14
    "nodeVersion": "24",          // 20, 22, 24
    "claudeCodeVersion": "latest"
  }
}
```

### Go

```json
{
  "templateOptions": {
    "goVersion": "1.25",          // 1.24, 1.25
    "nodeVersion": "24",          // 20, 22, 24
    "claudeCodeVersion": "latest"
  }
}
```

### TypeScript

```json
{
  "templateOptions": {
    "nodeVersion": "24",          // 20, 22, 24
    "claudeCodeVersion": "latest"
  }
}
```

## Mounting Agent Configs

The templates mount your local agent configurations:

```json
{
  "mounts": [
    "source=${localEnv:HOME}/.claude,target=/home/dev/.claude,type=bind",
    "source=${localEnv:HOME}/.claude.json,target=/home/dev/.claude.json,type=bind",
    "source=${localEnv:HOME}/.codex,target=/home/dev/.codex,type=bind",
    "source=${localEnv:HOME}/.gemini,target=/home/dev/.gemini,type=bind"
  ]
}
```

Ensure these directories exist on your host:
```bash
mkdir -p ~/.claude ~/.codex ~/.gemini
touch ~/.claude.json
```

## MCP Servers (Claude + Codex)

The templates auto-configure Context7 and Exa MCP servers for Claude Code and Codex on first start.
Provide API keys on your host so they get injected into the container:

```bash
export CONTEXT7_API_KEY=...
export EXA_API_KEY=...
```

The devcontainer uses `containerEnv` with `${localEnv:...}` to pass these into the container.

## Development

### Repository Structure

```
agent-containers/
├── src/
│   ├── features/
│   │   └── firewall/             # Network firewall feature
│   │       ├── devcontainer-feature.json
│   │       └── install.sh
│   ├── rust/                     # Rust template
│   │   ├── devcontainer-template.json
│   │   └── .devcontainer/
│   ├── python/                   # Python template
│   ├── go/                       # Go template
│   └── typescript/               # TypeScript template
├── test/                         # Test scripts
├── .github/workflows/            # CI/CD
└── README.md
```

### Local Testing

```bash
# Build a template locally
cd src/rust/.devcontainer
docker build -t agent-rust:test .

# Run tests
docker run --rm agent-rust:test /bin/bash -c "$(cat ../../../test/rust/test.sh)"
```

### Publishing

Push to `main` branch triggers automatic publishing to:
- `ghcr.io/blacktop/agent-containers/rust`
- `ghcr.io/blacktop/agent-containers/python`
- `ghcr.io/blacktop/agent-containers/go`
- `ghcr.io/blacktop/agent-containers/typescript`
- `ghcr.io/blacktop/agent-containers/firewall`

## License

MIT License - see [LICENSE](LICENSE) for details.
