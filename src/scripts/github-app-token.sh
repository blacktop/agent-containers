#!/bin/bash
# =============================================================================
# github-app-token.sh - Generate GitHub App Installation Access Token
# =============================================================================
# Generates a short-lived (1 hour) installation access token from a GitHub App.
# Use this to give AI agents limited, scoped access to repositories.
#
# Usage:
#   github-app-token.sh [OPTIONS]
#
# Options:
#   --app-id ID           GitHub App ID (or set GITHUB_APP_ID)
#   --install-id ID       Installation ID (or set GITHUB_APP_INSTALL_ID)
#   --key PATH            Path to private key .pem (or set GITHUB_APP_KEY_PATH)
#   --key-base64 BASE64   Base64-encoded private key (or set GITHUB_APP_KEY_BASE64)
#   --configure-git       Configure git to use the token for github.com
#   --export              Export token as GITHUB_TOKEN env var (eval-able output)
#   --quiet               Only output the token (or export statement)
#   --help                Show this help
#
# Environment Variables:
#   GITHUB_APP_ID         App ID (from App settings page)
#   GITHUB_APP_INSTALL_ID Installation ID (from /app/installations API)
#   GITHUB_APP_KEY_PATH   Path to .pem private key file
#   GITHUB_APP_KEY_BASE64 Base64-encoded private key (alternative to file)
#
# Example:
#   # Generate token
#   TOKEN=$(github-app-token.sh --app-id 123 --install-id 456 --key ~/.ssh/app.pem)
#
#   # Configure git automatically
#   github-app-token.sh --configure-git
#
#   # Use in shell config (exports GITHUB_TOKEN)
#   eval "$(github-app-token.sh --export)"
# =============================================================================

set -euo pipefail

# Defaults
APP_ID="${GITHUB_APP_ID:-}"
INSTALL_ID="${GITHUB_APP_INSTALL_ID:-}"
KEY_PATH="${GITHUB_APP_KEY_PATH:-}"
KEY_BASE64="${GITHUB_APP_KEY_BASE64:-}"
CONFIGURE_GIT=false
EXPORT_VAR=false
QUIET=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --app-id)
            APP_ID="$2"
            shift 2
            ;;
        --install-id)
            INSTALL_ID="$2"
            shift 2
            ;;
        --key)
            KEY_PATH="$2"
            shift 2
            ;;
        --key-base64)
            KEY_BASE64="$2"
            shift 2
            ;;
        --configure-git)
            CONFIGURE_GIT=true
            shift
            ;;
        --export)
            EXPORT_VAR=true
            QUIET=true
            shift
            ;;
        --quiet|-q)
            QUIET=true
            shift
            ;;
        --help|-h)
            head -42 "$0" | tail -40
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Validate required inputs
if [[ -z "$APP_ID" ]]; then
    echo "Error: --app-id or GITHUB_APP_ID required" >&2
    exit 1
fi

if [[ -z "$INSTALL_ID" ]]; then
    echo "Error: --install-id or GITHUB_APP_INSTALL_ID required" >&2
    exit 1
fi

if [[ -z "$KEY_PATH" && -z "$KEY_BASE64" ]]; then
    echo "Error: --key or --key-base64 (or env vars) required" >&2
    exit 1
fi

# Get private key content
if [[ -n "$KEY_BASE64" ]]; then
    PRIVATE_KEY=$(echo "$KEY_BASE64" | base64 -d)
elif [[ -f "$KEY_PATH" ]]; then
    PRIVATE_KEY=$(cat "$KEY_PATH")
else
    echo "Error: Private key not found at $KEY_PATH" >&2
    exit 1
fi

# -----------------------------------------------------------------------------
# Generate JWT
# -----------------------------------------------------------------------------
# JWT = base64(header).base64(payload).signature

# Header
HEADER=$(printf '{"alg":"RS256","typ":"JWT"}' | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')

# Payload (iat = now, exp = now + 10 min, iss = app_id)
NOW=$(date +%s)
IAT=$((NOW - 60))  # 1 minute in the past to account for clock drift
EXP=$((NOW + 600)) # 10 minutes from now

PAYLOAD=$(printf '{"iat":%d,"exp":%d,"iss":"%s"}' "$IAT" "$EXP" "$APP_ID" | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')

# Signature
SIGNATURE=$(printf '%s.%s' "$HEADER" "$PAYLOAD" | openssl dgst -sha256 -sign <(echo "$PRIVATE_KEY") | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')

JWT="${HEADER}.${PAYLOAD}.${SIGNATURE}"

# -----------------------------------------------------------------------------
# Exchange JWT for Installation Access Token
# -----------------------------------------------------------------------------
RESPONSE=$(curl -sf -X POST \
    -H "Authorization: Bearer $JWT" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/app/installations/${INSTALL_ID}/access_tokens" 2>&1) || {
    echo "Error: Failed to get installation token" >&2
    echo "$RESPONSE" >&2
    exit 1
}

TOKEN=$(echo "$RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [[ -z "$TOKEN" ]]; then
    echo "Error: No token in response" >&2
    echo "$RESPONSE" >&2
    exit 1
fi

# -----------------------------------------------------------------------------
# Output / Configure
# -----------------------------------------------------------------------------
if [[ "$CONFIGURE_GIT" == true ]]; then
    # Configure git to use token for github.com
    git config --global --unset-all url."https://x-access-token:${TOKEN}@github.com/".insteadOf >/dev/null 2>&1 || true
    git config --global --add url."https://x-access-token:${TOKEN}@github.com/".insteadOf "https://github.com/"
    git config --global --add url."https://x-access-token:${TOKEN}@github.com/".insteadOf "git@github.com:"

    if [[ "$QUIET" != true ]]; then
        echo "Git configured to use GitHub App token for github.com"
        EXPIRES=$(echo "$RESPONSE" | grep -o '"expires_at":"[^"]*"' | cut -d'"' -f4)
        echo "Token expires: $EXPIRES"
    fi
elif [[ "$EXPORT_VAR" == true ]]; then
    echo "export GITHUB_TOKEN='$TOKEN'"
else
    if [[ "$QUIET" == true ]]; then
        echo "$TOKEN"
    else
        EXPIRES=$(echo "$RESPONSE" | grep -o '"expires_at":"[^"]*"' | cut -d'"' -f4)
        echo "GitHub App Installation Token"
        echo "=============================="
        echo "Token: $TOKEN"
        echo "Expires: $EXPIRES"
        echo ""
        echo "To configure git:"
        echo "  git config --global url.\"https://x-access-token:\${TOKEN}@github.com/\".insteadOf \"git@github.com:\""
    fi
fi
