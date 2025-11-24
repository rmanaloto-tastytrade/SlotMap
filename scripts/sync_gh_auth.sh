#!/usr/bin/env bash
set -euo pipefail

# Sync GitHub CLI authentication from Mac to remote host
# This securely transfers the gh token to a remote host

REMOTE_HOST="${1:-c0802s4.ny5}"

echo "=== GitHub CLI Auth Sync ==="
echo "Syncing gh authentication to $REMOTE_HOST"

# Check if gh is authenticated locally
if ! gh auth status &>/dev/null; then
    echo "ERROR: gh is not authenticated on this machine"
    echo "Run: gh auth login"
    exit 1
fi

# Get the token from local gh
echo "Extracting GitHub token..."
GH_TOKEN=$(gh auth token 2>/dev/null)

if [[ -z "$GH_TOKEN" ]]; then
    echo "ERROR: Could not extract GitHub token"
    exit 1
fi

# Get the GitHub username
GH_USER=$(gh api user --jq .login 2>/dev/null || echo "unknown")
echo "GitHub user: $GH_USER"

# Transfer the token securely to remote host
echo "Configuring gh on remote host..."
ssh "$REMOTE_HOST" GH_TOKEN="$GH_TOKEN" bash <<'EOF'
set -euo pipefail

# Install gh if not present
if ! command -v gh &>/dev/null; then
    echo "gh CLI not found on remote, installing..."
    if [[ -f ~/.local/bin/gh ]]; then
        export PATH="~/.local/bin:\$PATH"
    else
        echo "ERROR: gh not installed on remote"
        echo "Run: ./scripts/update_tools_remote.sh on remote first"
        exit 1
    fi
fi

# Configure gh with the token via stdin (GH_TOKEN from ssh environment)
echo "$GH_TOKEN" | gh auth login --with-token

# Clear the token from environment after use
unset GH_TOKEN

# Verify authentication
if gh auth status &>/dev/null; then
    echo "✅ GitHub CLI authenticated successfully on remote"
    gh auth status
else
    echo "❌ GitHub CLI authentication failed"
    exit 1
fi
EOF

echo "✅ GitHub CLI authentication synced to $REMOTE_HOST"
echo ""
echo "Note: The token is stored in the remote's gh config at:"
echo "  ~/.config/gh/hosts.yml"
echo ""
echo "To revoke access later:"
echo "  Local:  gh auth logout"
echo "  Remote: ssh $REMOTE_HOST 'gh auth logout'"