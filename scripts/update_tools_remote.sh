#!/usr/bin/env bash
set -euo pipefail

# Update tools on Ubuntu/Debian remote host
echo "=== Updating Development Tools on Remote Host ==="

# Function to get latest version from GitHub (using curl if gh not available)
get_latest_github_release() {
  local repo=$1
  if command -v gh &>/dev/null; then
    gh api "repos/${repo}/releases/latest" --jq '.tag_name' 2>/dev/null | sed 's/^v//'
  else
    curl -s "https://api.github.com/repos/${repo}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/^v//'
  fi
}

# Install/Update GitHub CLI
echo "→ Checking GitHub CLI..."
LATEST_GH=$(get_latest_github_release "cli/cli")

if ! command -v gh &>/dev/null; then
  echo "  Installing GitHub CLI ${LATEST_GH}..."
  # Install gh CLI without sudo - download to user directory
  mkdir -p ~/.local/bin
  curl -L "https://github.com/cli/cli/releases/download/v${LATEST_GH}/gh_${LATEST_GH}_linux_amd64.tar.gz" | tar xz -C /tmp
  mv /tmp/gh_${LATEST_GH}_linux_amd64/bin/gh ~/.local/bin/
  rm -rf /tmp/gh_${LATEST_GH}_linux_amd64

  # Add to PATH if not already there
  if ! grep -q ".local/bin" ~/.bashrc 2>/dev/null; then
    echo 'export PATH=~/.local/bin:$PATH' >> ~/.bashrc
    echo "  Added ~/.local/bin to PATH in ~/.bashrc"
  fi
  export PATH=~/.local/bin:$PATH
else
  CURRENT_GH=$(gh --version 2>/dev/null | head -1 | awk '{print $3}')
  if [[ "$LATEST_GH" != "$CURRENT_GH" ]]; then
    echo "  Updating GitHub CLI: ${CURRENT_GH} → ${LATEST_GH}"
    curl -L "https://github.com/cli/cli/releases/download/v${LATEST_GH}/gh_${LATEST_GH}_linux_amd64.tar.gz" | tar xz -C /tmp
    mv /tmp/gh_${LATEST_GH}_linux_amd64/bin/gh ~/.local/bin/
    rm -rf /tmp/gh_${LATEST_GH}_linux_amd64
  else
    echo "  GitHub CLI is up-to-date: ${CURRENT_GH}"
  fi
fi

# Check Node.js/npm
if ! command -v npm &>/dev/null; then
  echo "ERROR: npm is not installed. Please install Node.js/npm first."
  echo "  For Ubuntu/Debian: sudo apt-get update && sudo apt-get install -y nodejs npm"
  exit 1
fi

# Configure npm to use user directory (if not already)
NPM_PREFIX=$(npm config get prefix)
if [[ "$NPM_PREFIX" == "/usr" ]] || [[ "$NPM_PREFIX" == "/usr/local" ]]; then
  echo "→ Configuring npm for user-level installations..."
  npm config set prefix ~/.npm-global
  mkdir -p ~/.npm-global/bin

  # Add to PATH if not already there
  if ! grep -q "npm-global/bin" ~/.bashrc 2>/dev/null; then
    echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.bashrc
    echo "  Added ~/.npm-global/bin to PATH in ~/.bashrc"
  fi
  export PATH=~/.npm-global/bin:$PATH
else
  echo "→ npm already configured for user-level: $NPM_PREFIX"
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
echo "→ GitHub CLI: $(gh --version 2>/dev/null | head -1 || echo 'not installed')"
echo "→ Node.js: $(node --version 2>/dev/null || echo 'not installed')"
echo "→ npm: $(npm --version 2>/dev/null || echo 'not installed')"
echo "→ devcontainer CLI: $(devcontainer --version 2>/dev/null || echo 'not installed')"
echo "→ npm prefix: $(npm config get prefix)"

echo ""
echo "✅ All tools updated successfully!"
echo ""
echo "To make PATH changes take effect in current shell:"
echo "  source ~/.bashrc"