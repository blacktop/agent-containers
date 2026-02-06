#!/bin/bash
# =============================================================================
# test.sh - Smoke tests for the yolo container image
# =============================================================================
# Run inside the yolo container:
#   docker run --rm yolo:test /bin/bash -c "$(cat test/yolo/test.sh)"
#
# Or with firewall testing (requires NET_ADMIN):
#   docker run --rm --cap-add=NET_ADMIN yolo:test /bin/bash -c "$(cat test/yolo/test.sh)"
# =============================================================================

set -e

echo "═══════════════════════════════════════════════════════════════"
echo "Yolo Container Smoke Tests"
echo "═══════════════════════════════════════════════════════════════"

# Track failures
FAILURES=0

pass() {
    echo "  [PASS] $1"
}

fail() {
    echo "  [FAIL] $1"
    FAILURES=$((FAILURES + 1))
}

check_command() {
    if command -v "$1" &>/dev/null; then
        pass "$1 found"
    else
        fail "$1 not found"
    fi
}

check_version() {
    local cmd="$1"
    local version_flag="${2:---version}"
    if $cmd $version_flag &>/dev/null; then
        local ver=$($cmd $version_flag 2>&1 | head -1)
        pass "$cmd: $ver"
    else
        fail "$cmd version check failed"
    fi
}

# ------------------------------------
echo ""
echo ">>> AI Agents"
# ------------------------------------
check_command claude
check_command codex
check_command gemini

# ------------------------------------
echo ""
echo ">>> Languages"
# ------------------------------------
check_version rustc
check_version cargo
check_version go version
check_version python3
check_version node
check_version npm

# ------------------------------------
echo ""
echo ">>> Language Tools"
# ------------------------------------
check_command uv
check_command ruff
check_command mypy
check_command gopls
check_command dlv
check_command staticcheck
check_command cargo-watch
check_command sccache
check_command tsc
check_command biome

# ------------------------------------
echo ""
echo ">>> Build Tools"
# ------------------------------------
check_command clang-21
check_command lld-21
check_command mold
check_command cmake
check_command pkg-config

# ------------------------------------
echo ""
echo ">>> Utilities"
# ------------------------------------
check_command git
check_command gh
check_command rg
check_command fd
check_command fzf
check_command jq
check_command delta
check_command tree
check_command htop
check_command fish
check_command curl
check_command wget

# ------------------------------------
echo ""
echo ">>> Scripts"
# ------------------------------------
if [ -x /usr/local/bin/entrypoint.sh ]; then
    pass "entrypoint.sh executable"
else
    fail "entrypoint.sh not executable"
fi

if [ -x /usr/local/bin/init-firewall ]; then
    pass "init-firewall executable"
else
    fail "init-firewall not executable"
fi

if [ -x /usr/local/bin/init-mcp.sh ]; then
    pass "init-mcp.sh executable"
else
    fail "init-mcp.sh not executable"
fi

if [ -x /usr/local/bin/init-gemini-extensions.sh ]; then
    pass "init-gemini-extensions.sh executable"
else
    fail "init-gemini-extensions.sh not executable"
fi

# ------------------------------------
echo ""
echo ">>> Environment"
# ------------------------------------
if [ -n "$CARGO_HOME" ]; then
    pass "CARGO_HOME set: $CARGO_HOME"
else
    fail "CARGO_HOME not set"
fi

if [ -n "$GOPATH" ]; then
    pass "GOPATH set: $GOPATH"
else
    fail "GOPATH not set"
fi

if [ -n "$LLVM_SYS_211_PREFIX" ]; then
    pass "LLVM_SYS_211_PREFIX set: $LLVM_SYS_211_PREFIX"
else
    fail "LLVM_SYS_211_PREFIX not set"
fi

# ------------------------------------
echo ""
echo ">>> Firewall (if NET_ADMIN available)"
# ------------------------------------
if iptables -L &>/dev/null 2>&1; then
    echo "NET_ADMIN capability detected"

    # Test firewall init
    export FIREWALL_ENABLED=true
    if sudo /usr/local/bin/init-firewall; then
        pass "Firewall initialized"

        # Test that blocked domain fails
        if curl -sf --connect-timeout 3 https://example.com &>/dev/null; then
            fail "example.com should be blocked"
        else
            pass "example.com blocked"
        fi

        # Test that allowed domain works
        if curl -sf --connect-timeout 5 https://api.github.com &>/dev/null; then
            pass "api.github.com accessible"
        else
            # May fail due to rate limiting, don't fail test
            echo "  [WARN] api.github.com check inconclusive"
        fi
    else
        fail "Firewall init failed"
    fi
else
    echo "  [SKIP] No NET_ADMIN capability (run with --cap-add=NET_ADMIN)"
fi

# ------------------------------------
echo ""
echo "═══════════════════════════════════════════════════════════════"
if [ $FAILURES -eq 0 ]; then
    echo "All tests passed!"
    exit 0
else
    echo "Tests completed with $FAILURES failure(s)"
    exit 1
fi
