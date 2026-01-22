#!/bin/bash
set -e

echo "Testing Go Agent Sandbox..."

# Check Go installation
if ! command -v go &>/dev/null; then
    echo "FAIL: go not found"
    exit 1
fi
echo "PASS: go $(go version | cut -d' ' -f3)"

# Check GOPATH
if [ -z "$GOPATH" ]; then
    echo "FAIL: GOPATH not set"
    exit 1
fi
echo "PASS: GOPATH=$GOPATH"

# Check Node.js (for Claude Code)
if ! command -v node &>/dev/null; then
    echo "FAIL: node not found"
    exit 1
fi
echo "PASS: node $(node --version)"

# Check Claude Code CLI
if ! command -v claude &>/dev/null; then
    echo "FAIL: claude CLI not found"
    exit 1
fi
echo "PASS: claude CLI available"

# Check Codex CLI
if ! command -v codex &>/dev/null; then
    echo "FAIL: codex CLI not found"
    exit 1
fi
echo "PASS: codex CLI available"

# Check Gemini CLI
if ! command -v gemini &>/dev/null; then
    echo "FAIL: gemini CLI not found"
    exit 1
fi
echo "PASS: gemini CLI available"

# Check fish shell
if ! command -v fish &>/dev/null; then
    echo "FAIL: fish not found"
    exit 1
fi
echo "PASS: fish $(fish --version | cut -d' ' -f3)"

# Check common tools
for cmd in git gh fzf jq delta; do
    if ! command -v $cmd &>/dev/null; then
        echo "FAIL: $cmd not found"
        exit 1
    fi
done
echo "PASS: common tools available"

# Check Go tools
for tool in gopls dlv golangci-lint staticcheck; do
    if ! command -v $tool &>/dev/null; then
        echo "WARN: $tool may not be installed"
    fi
done
echo "PASS: Go tools checked"

echo ""
echo "All Go template tests passed!"
