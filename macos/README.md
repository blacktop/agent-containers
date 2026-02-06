# macOS Native Tools

Native macOS tools for running AI agents without containers.

## Overview

| Tool | Purpose |
|------|---------|
| `sandbox/agent.sb` | Basic macOS sandbox profile |
| `sandbox/agent-xcode.sb` | Sandbox with Xcode/simulator access |
| `pf/agent.pf.conf` | pf firewall allowlist rules |
| `pf/install-anchor.sh` | pf anchor setup script |
| `fish/agent.fish` | Fish shell functions |
| `fish/install.fish` | Fish installer |

## Quick Start

```bash
# Install fish functions
cd macos/fish
./install.fish

# Run agent with sandbox
agent-native claude

# Run agent with Xcode access
agent-native --xcode claude

# Run agent with pf firewall
agent-native --pf claude
```

## Sandbox Profiles

### Basic Sandbox (`agent.sb`)

Restricts agents to:
- Workspace directory (read/write)
- Agent config dirs (`~/.claude`, `~/.codex`, `~/.gemini`)
- Temp directories
- Outbound HTTPS/HTTP/DNS/SSH

Blocks:
- `~/.ssh`, `~/.aws`, `~/.gnupg`, `~/.kube`
- System directories (write)
- Browser data
- Other volumes

Usage:
```bash
sandbox-exec -f sandbox/agent.sb \
    -D WORKSPACE=/path/to/project \
    -D HOME=$HOME \
    claude --dangerously-skip-permissions
```

### Xcode Sandbox (`agent-xcode.sb`)

Same as basic, plus:
- `/Applications/Xcode.app` (read)
- `/Library/Developer/*` (read)
- `~/Library/Developer/CoreSimulator` (read/write)
- CoreSimulator Mach services

Usage:
```bash
sandbox-exec -f sandbox/agent-xcode.sb \
    -D WORKSPACE=/path/to/ios-project \
    -D HOME=$HOME \
    claude --dangerously-skip-permissions
```

## pf Firewall

IP-level filtering via macOS packet filter. More restrictive than sandbox alone.

### Install

```bash
# Enable pf anchor
sudo ./pf/install-anchor.sh enable

# Check status
sudo ./pf/install-anchor.sh status

# Refresh IP tables
sudo ./pf/install-anchor.sh refresh

# Disable
sudo ./pf/install-anchor.sh disable
```

### Allowed Destinations

Same as Docker firewall:
- GitHub (git, API, packages)
- npm, PyPI, crates.io, Go proxy
- Anthropic, OpenAI, Google AI APIs
- Debian/Ubuntu repos
- Sentry, Context7, Astral

### How It Works

1. Creates pf anchor `com.apple/agent`
2. Resolves allowed domains to IPs
3. Populates pf tables (`github_ips`, `allowed_ips`)
4. Applies rules that only allow traffic to those IPs

Note: The sandbox already restricts ports. pf adds IP-level filtering on top.

## Fish Functions

### `agent`

Run AI agent in Docker container (yolo mode).

```fish
agent claude                    # Run Claude on cwd
agent -w ~/project codex        # Specific workspace
agent --no-firewall gemini      # Disable firewall
```

### `agent-native`

Run AI agent directly on macOS with sandbox.

```fish
agent-native claude             # Basic sandbox
agent-native --xcode claude     # With Xcode access
agent-native --pf claude        # With pf firewall
agent-native --no-sandbox claude # DANGEROUS: no sandbox
```

### `agent-build`

Build the yolo Docker image.

```fish
agent-build                     # Build locally
agent-build --push              # Build and push
agent-build -t my-image:tag     # Custom tag
```

### `agent-spawn`

Create jj workspace and launch agent.

```fish
agent-spawn feature-auth        # New workspace from @
agent-spawn fix -r main         # From main branch
agent-spawn api -a codex        # Use Codex instead
```

### `agent-list`

List active jj workspaces.

### `agent-cleanup`

Remove jj workspace.

```fish
agent-cleanup feature-auth      # With confirmation
agent-cleanup -f fix            # Force remove
```

## Installation

### Fish Functions

```bash
# Option 1: Source from config.fish (recommended)
cd macos/fish
./install.fish

# Option 2: Copy to functions directory
./install.fish --copy

# Uninstall
./install.fish --uninstall
```

### pf Firewall

Requires sudo. No permanent installation needed - rules are loaded on demand.

```bash
# Enable when running agent
sudo ./pf/install-anchor.sh enable
agent-native claude
sudo ./pf/install-anchor.sh disable

# Or use the --pf flag (handles enable/disable automatically)
agent-native --pf claude
```

## Security Notes

1. **Sandbox is not bulletproof** - Determined code could potentially escape
2. **pf adds defense-in-depth** - Even if sandbox is bypassed, network is restricted
3. **Xcode sandbox is more permissive** - Only use when building iOS/macOS apps
4. **Review your agent's actions** - These tools reduce risk, not eliminate it

## Comparison: Docker vs Native

| Feature | Docker (yolo) | Native (sandbox) |
|---------|---------------|------------------|
| Isolation | Full container | Process sandbox |
| Network | iptables + ipset | sandbox + optional pf |
| Performance | ~5% overhead | Native speed |
| Xcode/Simulators | Not supported | Supported |
| Apple SDKs | Limited | Full access |
| Setup | Just Docker | Fish + macos/ files |

**Use Docker when:**
- You don't need Xcode/simulators
- You want strongest isolation
- Cross-platform consistency matters

**Use Native when:**
- Building iOS/macOS apps
- Performance is critical
- You need Apple frameworks
