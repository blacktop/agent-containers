#!/bin/bash
set -e

echo "Testing TypeScript Agent Sandbox..."

# Check Node.js installation
if ! command -v node &>/dev/null; then
    echo "FAIL: node not found"
    exit 1
fi
echo "PASS: node $(node --version)"

# Check npm
if ! command -v npm &>/dev/null; then
    echo "FAIL: npm not found"
    exit 1
fi
echo "PASS: npm $(npm --version)"

# Check TypeScript
if ! command -v tsc &>/dev/null; then
    echo "FAIL: tsc not found"
    exit 1
fi
echo "PASS: tsc $(tsc --version | cut -d' ' -f2)"

# Check pnpm
if ! command -v pnpm &>/dev/null; then
    echo "FAIL: pnpm not found"
    exit 1
fi
echo "PASS: pnpm $(pnpm --version)"

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

# Check global npm packages
for pkg in eslint prettier ts-node; do
    if ! npm list -g $pkg &>/dev/null; then
        echo "WARN: $pkg may not be installed globally"
    fi
done
echo "PASS: npm global packages checked"

echo ""
echo "All TypeScript template tests passed!"
