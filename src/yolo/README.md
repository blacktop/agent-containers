# Yolo Mode

Universal AI agent container for running Claude Code, Codex, and Gemini CLI in fully autonomous mode.

## Features

- **All Languages**: Rust, Python, Go, TypeScript/Node pre-installed
- **All Agents**: Claude Code, Codex, Gemini CLI ready to use
- **Network Firewall**: Default-deny with allowlist (requires `--cap-add=NET_ADMIN`)
- **Fish Shell**: Hydro prompt, fzf integration

## Quick Start

```bash
# Build the image
docker build -t yolo -f src/yolo/Dockerfile src/yolo

# Run Claude Code
docker run -it --rm --cap-add=NET_ADMIN \
    -v $(pwd):/workspace \
    -v ~/.claude:/home/dev/.claude \
    yolo claude

# Run Codex
docker run -it --rm --cap-add=NET_ADMIN \
    -v $(pwd):/workspace \
    -v ~/.codex:/home/dev/.codex \
    yolo codex

# Run Gemini CLI
docker run -it --rm --cap-add=NET_ADMIN \
    -v $(pwd):/workspace \
    -v ~/.gemini:/home/dev/.gemini \
    yolo gemini
```

## Usage

```
docker run [OPTIONS] yolo COMMAND [ARGS...]

Commands:
  claude      Run Claude Code (--dangerously-skip-permissions)
  codex       Run Codex (--approval-mode full-auto)
  gemini      Run Gemini CLI (--yolo)
  bash        Interactive bash shell
  fish        Interactive fish shell
  install-all Show installed agent versions

Options:
  --cap-add=NET_ADMIN    Enable network firewall (recommended)
  -v PATH:/workspace     Mount your project directory
  -v ~/.claude:/home/dev/.claude   Mount Claude auth
  -v ~/.codex:/home/dev/.codex     Mount Codex auth
  -v ~/.gemini:/home/dev/.gemini   Mount Gemini auth
```

## Firewall

The container includes a default-deny network firewall that only allows:

- **AI APIs**: Anthropic, OpenAI, Google AI
- **Package Registries**: npm, PyPI, crates.io, Go proxy
- **Code Hosting**: GitHub (git, API, packages)
- **OS Packages**: Debian/Ubuntu repos

### Disable Firewall

```bash
docker run -it --rm \
    -e FIREWALL_ENABLED=false \
    -v $(pwd):/workspace \
    yolo claude
```

### Customize Allowed Domains

```bash
docker run -it --rm --cap-add=NET_ADMIN \
    -e CUSTOMDOMAINS="api.example.com,cdn.example.com" \
    -v $(pwd):/workspace \
    yolo claude
```

### Firewall Options

| Variable | Default | Description |
|----------|---------|-------------|
| `FIREWALL_ENABLED` | `true` | Enable/disable firewall |
| `ALLOWGITHUB` | `true` | GitHub (git, API, packages) |
| `ALLOWNPM` | `true` | npm registry |
| `ALLOWPYPI` | `true` | PyPI |
| `ALLOWCRATES` | `true` | crates.io |
| `ALLOWGO` | `true` | Go proxy |
| `ALLOWANTHROPIC` | `true` | Anthropic API |
| `ALLOWOPENAI` | `true` | OpenAI API |
| `ALLOWGOOGLE` | `true` | Google AI API |
| `ALLOWDEBIAN` | `true` | Debian/Ubuntu repos |
| `CUSTOMDOMAINS` | | Comma-separated domains |

## MCP Servers

Pass API keys to auto-configure MCP servers:

```bash
docker run -it --rm --cap-add=NET_ADMIN \
    -e CONTEXT7_API_KEY=your-key \
    -e EXA_API_KEY=your-key \
    -v $(pwd):/workspace \
    -v ~/.claude:/home/dev/.claude \
    yolo claude
```

## GitHub App Authentication (Recommended)

Use a GitHub App for least-privilege git access. The agent can push code but cannot delete repos, change settings, or access other repos.

### Setup

1. Create a GitHub App at https://github.com/settings/apps/new
   - **Permissions**: Contents (Read & write), Pull requests (Read & write), Metadata (Read)
   - **No admin, secrets, or workflow permissions**

2. Generate a private key and install the app on your repos

3. Run the setup helper to get your IDs:
   ```bash
   ./src/scripts/github-app-setup.sh
   ```

4. Set environment variables:
   ```bash
   export GITHUB_APP_ID=123456
   export GITHUB_APP_INSTALL_ID=12345678
   export GITHUB_APP_KEY_BASE64=$(base64 -i ~/.ssh/my-app.pem | tr -d '\n')
   ```

5. Run with GitHub App auth:
   ```bash
   docker run -it --rm --cap-add=NET_ADMIN \
       -e GITHUB_APP_ID \
       -e GITHUB_APP_INSTALL_ID \
       -e GITHUB_APP_KEY_BASE64 \
       -v $(pwd):/workspace \
       -v ~/.claude:/home/dev/.claude \
       yolo claude
   ```

### What the Agent CAN'T Do

| Action | Allowed |
|--------|---------|
| Push to branches | Yes |
| Create PRs | Yes |
| Delete repository | **No** |
| Change repo settings | **No** |
| Add collaborators | **No** |
| Access other repos | **No** |
| Read/write secrets | **No** |
| Modify GitHub Actions | **No** |

## Pre-installed Tools

### Languages
- **Rust**: stable toolchain, cargo-watch, cargo-edit, sccache
- **Go**: 1.24, gopls, delve, staticcheck
- **Python**: 3.13 via uv, ruff, mypy
- **Node**: 22, TypeScript, tsx, Biome

### Build Tools
- LLVM 21, Clang, mold linker
- CMake, pkg-config

### Utilities
- git, gh (GitHub CLI), delta
- ripgrep, fd, fzf, jq, tree, htop

## Fish Shell Functions

The container includes fish shell with agent functions. See `macos/fish/agent.fish` for the full implementation.

## Image Size

~4GB (all languages included)

## Architecture

Supports both `amd64` and `arm64` (Apple Silicon).
