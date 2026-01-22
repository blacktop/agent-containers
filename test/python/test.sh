#!/bin/bash
set -e

echo "Testing Python Agent Sandbox..."

# Check Python installation
if ! command -v python3 &>/dev/null; then
    echo "FAIL: python3 not found"
    exit 1
fi
echo "PASS: python $(python3 --version | cut -d' ' -f2)"

# Check uv
if ! command -v uv &>/dev/null; then
    echo "FAIL: uv not found"
    exit 1
fi
echo "PASS: uv $(uv --version | cut -d' ' -f2)"

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

# Check Python tools installed via uv
for tool in ruff mypy pytest; do
    if ! uv tool list 2>/dev/null | grep -q "^$tool"; then
        echo "WARN: $tool may not be installed via uv"
    fi
done
echo "PASS: Python tools checked"

echo ""
echo "All Python template tests passed!"
