#!/bin/bash
# =============================================================================
# init-github-app.sh - Initialize GitHub App token in devcontainer
# =============================================================================
# Called from postStartCommand to configure git with GitHub App credentials.
# Silently skips if credentials are not provided.
#
# Required Environment Variables (all must be set):
#   GITHUB_APP_ID           - App ID from GitHub App settings
#   GITHUB_APP_INSTALL_ID   - Installation ID
#   GITHUB_APP_KEY_BASE64   - Base64-encoded private key
#
# Optional:
#   GITHUB_APP_KEY_PATH     - Path to .pem file (alternative to BASE64)
# =============================================================================

set -euo pipefail

# Check if GitHub App credentials are provided
if [[ -z "${GITHUB_APP_ID:-}" ]]; then
    exit 0  # Silent skip - no app configured
fi

if [[ -z "${GITHUB_APP_INSTALL_ID:-}" ]]; then
    echo "Warning: GITHUB_APP_ID set but GITHUB_APP_INSTALL_ID missing" >&2
    exit 0
fi

if [[ -z "${GITHUB_APP_KEY_BASE64:-}" && -z "${GITHUB_APP_KEY_PATH:-}" ]]; then
    echo "Warning: GITHUB_APP_ID set but no private key provided" >&2
    exit 0
fi

# Find the token script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOKEN_SCRIPT="${SCRIPT_DIR}/github-app-token.sh"

if [[ ! -x "$TOKEN_SCRIPT" ]]; then
    # Try installed location
    TOKEN_SCRIPT="/usr/local/bin/github-app-token.sh"
fi

if [[ ! -x "$TOKEN_SCRIPT" ]]; then
    echo "Warning: github-app-token.sh not found" >&2
    exit 0
fi

# Generate token and configure git
echo "Configuring git with GitHub App token..."
"$TOKEN_SCRIPT" --configure-git --quiet

echo "GitHub App authentication configured"
