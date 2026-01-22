#!/bin/bash
set -e

echo "Testing Rust Agent Sandbox..."

# Check Rust installation
if ! command -v rustc &>/dev/null; then
    echo "FAIL: rustc not found"
    exit 1
fi
echo "PASS: rustc $(rustc --version | cut -d' ' -f2)"

# Check Cargo
if ! command -v cargo &>/dev/null; then
    echo "FAIL: cargo not found"
    exit 1
fi
echo "PASS: cargo available"

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
for cmd in git gh ripgrep fzf jq delta; do
    if [ "$cmd" = "ripgrep" ]; then
        if ! command -v rg &>/dev/null && ! command -v ripgrep &>/dev/null; then
            echo "FAIL: ripgrep not found"
            exit 1
        fi
    else
        if ! command -v $cmd &>/dev/null; then
            echo "FAIL: $cmd not found"
            exit 1
        fi
    fi
done
echo "PASS: common tools available"

# Check Rust tools
for cmd in cargo-watch cargo-expand; do
    if ! cargo install --list | grep -q "^$cmd"; then
        echo "WARN: $cmd may not be installed"
    fi
done
echo "PASS: Rust tools checked"

echo ""
echo "All Rust template tests passed!"
