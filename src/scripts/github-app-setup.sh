#!/bin/bash
# =============================================================================
# github-app-setup.sh - Interactive setup for GitHub App credentials
# =============================================================================
# Helps you find your App ID and Installation ID, and test authentication.
#
# Usage:
#   github-app-setup.sh
#
# Prerequisites:
#   - GitHub App created (https://github.com/settings/apps/new)
#   - Private key downloaded (.pem file)
#   - App installed on your account/repos
# =============================================================================

set -euo pipefail

echo "=========================================="
echo "GitHub App Setup for AI Agent Containers"
echo "=========================================="
echo ""

# Step 1: App ID
echo "STEP 1: App ID"
echo "--------------"
echo "Find your App ID at: https://github.com/settings/apps"
echo "Click on your app -> scroll down to 'App ID'"
echo ""
read -p "Enter your App ID: " APP_ID

if [[ -z "$APP_ID" ]]; then
    echo "Error: App ID required"
    exit 1
fi

# Step 2: Private Key
echo ""
echo "STEP 2: Private Key"
echo "-------------------"
echo "You should have downloaded a .pem file when you created the app."
echo ""
read -p "Enter path to private key .pem file: " KEY_PATH

if [[ ! -f "$KEY_PATH" ]]; then
    echo "Error: File not found: $KEY_PATH"
    exit 1
fi

# Step 3: Get Installation ID
echo ""
echo "STEP 3: Finding Installation ID"
echo "--------------------------------"
echo "Authenticating with GitHub..."

# Generate JWT
HEADER=$(printf '{"alg":"RS256","typ":"JWT"}' | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')
NOW=$(date +%s)
IAT=$((NOW - 60))
EXP=$((NOW + 600))
PAYLOAD=$(printf '{"iat":%d,"exp":%d,"iss":"%s"}' "$IAT" "$EXP" "$APP_ID" | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')
SIGNATURE=$(printf '%s.%s' "$HEADER" "$PAYLOAD" | openssl dgst -sha256 -sign "$KEY_PATH" | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')
JWT="${HEADER}.${PAYLOAD}.${SIGNATURE}"

# Get installations
echo "Fetching installations..."
INSTALLATIONS=$(curl -sf \
    -H "Authorization: Bearer $JWT" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/app/installations" 2>&1) || {
    echo "Error: Failed to fetch installations. Check your App ID and private key."
    exit 1
}

# Parse installations
INSTALL_COUNT=$(echo "$INSTALLATIONS" | grep -c '"id":' || echo "0")

if [[ "$INSTALL_COUNT" -eq 0 ]]; then
    echo ""
    echo "No installations found!"
    echo "Please install your app: https://github.com/settings/apps -> Your App -> Install App"
    exit 1
fi

echo ""
echo "Found $INSTALL_COUNT installation(s):"
echo ""

# Show installations (use jq if available, fall back to grep)
if command -v jq &>/dev/null; then
    echo "$INSTALLATIONS" | jq -r '.[] | "  Installation ID: \(.id) (account: \(.account.login))"'
else
    # Fallback: extract first-level id fields (not nested ones)
    echo "$INSTALLATIONS" | grep -o '"id":[0-9]*' | head -n "$INSTALL_COUNT" | while read -r idline; do
        ID=$(echo "$idline" | grep -o '[0-9]\+')
        echo "  Installation ID: $ID"
    done
    echo "  (install jq for better output)"
fi

echo ""
read -p "Enter the Installation ID to use: " INSTALL_ID

# Step 4: Test token generation
echo ""
echo "STEP 4: Testing Token Generation"
echo "---------------------------------"

TOKEN_RESPONSE=$(curl -sf -X POST \
    -H "Authorization: Bearer $JWT" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/app/installations/${INSTALL_ID}/access_tokens" 2>&1) || {
    echo "Error: Failed to generate token"
    exit 1
}

TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
EXPIRES=$(echo "$TOKEN_RESPONSE" | grep -o '"expires_at":"[^"]*"' | cut -d'"' -f4)

if [[ -z "$TOKEN" ]]; then
    echo "Error: No token in response"
    echo "$TOKEN_RESPONSE"
    exit 1
fi

echo "Success! Token generated (expires: $EXPIRES)"

# Step 5: Test API access
echo ""
echo "STEP 5: Testing API Access"
echo "--------------------------"

USER_INFO=$(curl -sf \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/user" 2>&1) || true

if [[ -n "$USER_INFO" ]]; then
    BOT_NAME=$(echo "$USER_INFO" | grep -o '"login":"[^"]*"' | cut -d'"' -f4)
    echo "Authenticated as: $BOT_NAME"
fi

# List accessible repos
echo ""
echo "Repositories accessible by this installation:"
REPOS=$(curl -sf \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/installation/repositories" 2>&1) || true

echo "$REPOS" | grep -o '"full_name":"[^"]*"' | cut -d'"' -f4 | while read -r repo; do
    echo "  - $repo"
done

# Step 6: Generate environment variables
echo ""
echo "=========================================="
echo "SETUP COMPLETE"
echo "=========================================="
echo ""
echo "Add these to your shell config (~/.bashrc, ~/.zshrc, or ~/.config/fish/config.fish):"
echo ""
echo "  export GITHUB_APP_ID='$APP_ID'"
echo "  export GITHUB_APP_INSTALL_ID='$INSTALL_ID'"
echo "  export GITHUB_APP_KEY_BASE64='$(cat "$KEY_PATH" | base64 | tr -d '\n')'"
echo ""
echo "Or for devcontainer.json, add to containerEnv:"
echo ""
echo '  "GITHUB_APP_ID": "${localEnv:GITHUB_APP_ID}",'
echo '  "GITHUB_APP_INSTALL_ID": "${localEnv:GITHUB_APP_INSTALL_ID}",'
echo '  "GITHUB_APP_KEY_BASE64": "${localEnv:GITHUB_APP_KEY_BASE64}"'
echo ""
echo "Then in postStartCommand, add:"
echo '  /usr/local/bin/init-github-app.sh || true;'
echo ""
