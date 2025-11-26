#!/usr/bin/env bash
set -euo pipefail

# Sync GitHub CLI authentication from Mac to remote host
# This securely transfers the gh token to a remote host

# Load local config file if present
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_ENV_FILE="${CONFIG_ENV_FILE:-$REPO_ROOT/config/env/devcontainer.env}"
if [[ -f "$CONFIG_ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_ENV_FILE"
fi

# Use CLI arg, then config file, then fail
REMOTE_HOST="${1:-${DEVCONTAINER_REMOTE_HOST:-}}"

if [[ -z "$REMOTE_HOST" ]]; then
  echo "ERROR: Remote host is required." >&2
  echo "Usage: $0 <remote-host>" >&2
  echo "Or set DEVCONTAINER_REMOTE_HOST in config/env/devcontainer.env" >&2
  exit 1
fi

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