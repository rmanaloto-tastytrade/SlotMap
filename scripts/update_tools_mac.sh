#!/usr/bin/env bash
set -euo pipefail

# Update tools on macOS using Homebrew
echo "=== Updating Development Tools on macOS ==="

# Function to get latest version from GitHub
get_latest_github_release() {
  local repo=$1
  gh api "repos/${repo}/releases/latest" --jq '.tag_name' 2>/dev/null | sed 's/^v//'
}

# Update Homebrew first
echo "→ Updating Homebrew..."
brew update

# Update/Install gh CLI
echo "→ Updating GitHub CLI..."
if brew list gh &>/dev/null; then
  brew upgrade gh
else
  brew install gh
fi
echo "  GitHub CLI version: $(gh --version | head -1)"

# Update/Install Node.js if needed (for npm)
echo "→ Checking Node.js..."
if ! brew list node &>/dev/null; then
  echo "  Installing Node.js..."
  brew install node
else
  echo "  Node.js already installed: $(node --version)"
fi

# Configure npm to use user directory (if not already)
if [[ "$(npm config get prefix)" == "/usr/local" ]] || [[ "$(npm config get prefix)" == "/usr" ]]; then
  echo "→ Configuring npm for user-level installations..."
  npm config set prefix ~/.npm-global
  mkdir -p ~/.npm-global/bin

  # Add to PATH if not already there
  if ! grep -q "npm-global/bin" ~/.zshrc 2>/dev/null; then
    echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.zshrc
    echo "  Added ~/.npm-global/bin to PATH in ~/.zshrc"
  fi
  export PATH=~/.npm-global/bin:$PATH
fi

# Get and install latest devcontainer CLI
echo "→ Checking devcontainer CLI..."
LATEST_DEVCONTAINER=$(get_latest_github_release "devcontainers/cli")
CURRENT_DEVCONTAINER=$(devcontainer --version 2>/dev/null || echo "0.0.0")

if [[ "$LATEST_DEVCONTAINER" != "$CURRENT_DEVCONTAINER" ]]; then
  echo "  Updating devcontainer CLI: ${CURRENT_DEVCONTAINER} → ${LATEST_DEVCONTAINER}"
  npm install -g @devcontainers/cli@${LATEST_DEVCONTAINER}
else
  echo "  devcontainer CLI is up-to-date: ${CURRENT_DEVCONTAINER}"
fi

# Verify installations
echo ""
echo "=== Tool Versions ==="
echo "→ GitHub CLI: $(gh --version | head -1)"
echo "→ Node.js: $(node --version)"
echo "→ npm: $(npm --version)"
echo "→ devcontainer CLI: $(devcontainer --version)"
echo "→ npm prefix: $(npm config get prefix)"

echo ""
echo "✅ All tools updated successfully!"
echo ""
echo "To make PATH changes take effect in current shell:"
echo "  source ~/.zshrc"