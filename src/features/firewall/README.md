
# Network Firewall Sandbox (firewall)

Default-deny network firewall with allowlist for AI coding agents. Permits GitHub, npm, PyPI, crates.io, Go modules, Anthropic/OpenAI/Google APIs, and VS Code services.

## Example Usage

```json
"features": {
    "ghcr.io/blacktop/agent-containers/firewall:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| allowGithub | Allow GitHub (git, API, packages, ghcr.io) | boolean | true |
| allowNpm | Allow npm registry | boolean | true |
| allowPypi | Allow PyPI (Python packages) | boolean | true |
| allowCrates | Allow crates.io (Rust packages) | boolean | true |
| allowGo | Allow Go module proxy | boolean | true |
| allowAnthropic | Allow Anthropic API (Claude) | boolean | true |
| allowOpenai | Allow OpenAI API | boolean | true |
| allowGoogle | Allow Google AI API | boolean | true |
| allowVscode | Allow VS Code services | boolean | true |
| allowDebian | Allow Debian/Ubuntu package repos | boolean | true |
| customDomains | Additional domains to allow (comma-separated) | string | - |



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/blacktop/agent-containers/blob/main/src/features/firewall/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
