#!/usr/bin/env bash
set -euo pipefail

# This script is meant to be executed directly on the remote Linux host.
# It rebuilds the sandbox workspace and launches the Dev Container via the
# Dev Containers CLI. No git changes occur in the sandbox; it is recreated
# from the clean repo checkout on every run.
#
# Directory layout (defaults can be overridden via environment variables):
#   REPO_PATH    : $HOME/dev/github/SlotMap            (clean git clone)
#   SANDBOX_PATH : $HOME/dev/devcontainers/SlotMap     (recreated each run)
#   KEY_CACHE    : $HOME/macbook_ssh_keys              (rsynced from your Mac)
#
# Requirements: devcontainer CLI installed on the remote host, Docker running,
# and your public key(s) copied into $KEY_CACHE (e.g., ~/.ssh/id_ed25519.pub).

REPO_PATH=${REPO_PATH:-"$HOME/dev/github/SlotMap"}
SANDBOX_PATH=${SANDBOX_PATH:-"$HOME/dev/devcontainers/SlotMap"}
KEY_CACHE=${KEY_CACHE:-"$HOME/macbook_ssh_keys"}
SSH_SUBDIR=".devcontainer/ssh"
DEV_IMAGE=${DEVCONTAINER_IMAGE:-"devcontainer:local"}
BASE_IMAGE=${DEVCONTAINER_BASE_IMAGE:-"dev-base:local"}
# SSH port for container (host port that maps to container's internal 2222)
DEVCONTAINER_SSH_PORT=${DEVCONTAINER_SSH_PORT:-9222}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER_USER=${CONTAINER_USER:-$(id -un)}
CONTAINER_UID=${CONTAINER_UID:-$(id -u)}
CONTAINER_GID=${CONTAINER_GID:-$(id -g)}
# Get latest devcontainer CLI version from GitHub
get_latest_devcontainer_version() {
  # Try using curl first (doesn't require authentication)
  local version
  version=$(curl -s "https://api.github.com/repos/devcontainers/cli/releases/latest" 2>/dev/null | grep '"tag_name":' | sed -E 's/.*"v?([^"]+)".*/\1/')

  # Check if we got a valid version (should start with a number)
  if [[ "$version" =~ ^[0-9] ]]; then
    echo "$version"
  else
    # Fallback to known good version
    echo "0.80.2"
  fi
}

# Use latest version unless overridden
if [[ -z "${DEVCONTAINER_CLI_VERSION:-}" ]]; then
  DEVCONTAINER_CLI_VERSION=$(get_latest_devcontainer_version)
  echo "[remote] Using latest devcontainer CLI version: $DEVCONTAINER_CLI_VERSION"
else
  echo "[remote] Using specified devcontainer CLI version: $DEVCONTAINER_CLI_VERSION"
fi
DOCKER_CONTEXT=${DOCKER_CONTEXT:-}
WORKSPACE_PATH=${WORKSPACE_PATH:-"/home/${CONTAINER_USER}/dev/devcontainers/workspace"}

echo "[remote] Repo source       : $REPO_PATH"
echo "[remote] Sandbox workspace : $SANDBOX_PATH"
echo "[remote] Mac key cache     : $KEY_CACHE"
echo "[remote] Workspace mount   : $WORKSPACE_PATH"
echo

if [[ -n "$DOCKER_CONTEXT" ]]; then
  echo "[remote] Using docker context: $DOCKER_CONTEXT"
  export DOCKER_CONTEXT
fi

ensure_devcontainer_cli() {
  # Always ensure ~/.npm-global/bin is in PATH first
  if [[ -d "$HOME/.npm-global/bin" ]]; then
    export PATH="$HOME/.npm-global/bin:$PATH"
  fi

  if command -v devcontainer >/dev/null 2>&1; then
    local current
    current="$(devcontainer --version 2>/dev/null || true)"
    if [[ "$current" == "$DEVCONTAINER_CLI_VERSION" ]]; then
      echo "[remote] Found devcontainer CLI $current."
      return 0
    fi
    if [[ "${SKIP_DEVCONTAINER_UPGRADE:-0}" == "1" ]]; then
      echo "[remote] WARNING: devcontainer CLI version $current != $DEVCONTAINER_CLI_VERSION, but skipping upgrade (SKIP_DEVCONTAINER_UPGRADE=1)"
      echo "[remote] Using existing version: $current"
      return 0
    else
      echo "[remote] devcontainer CLI version $current != $DEVCONTAINER_CLI_VERSION; upgrading..."
    fi
  else
    echo "[remote] devcontainer CLI not found; installing $DEVCONTAINER_CLI_VERSION..."
  fi

  if ! command -v npm >/dev/null 2>&1; then
    echo "[remote] ERROR: npm is required to install @devcontainers/cli. Install Node.js/npm on the host and rerun." >&2
    exit 1
  fi

  # Check npm configuration and permissions
  local npm_prefix
  npm_prefix="$(npm config get prefix)"
  echo "[remote] npm global prefix: $npm_prefix"
  echo "[remote] npm user: $(whoami)"

  # Check if we can write to npm's global directory
  if [[ ! -w "$npm_prefix/lib/node_modules" ]]; then
    echo "[remote] WARNING: Cannot write to $npm_prefix/lib/node_modules"
    echo "[remote] Setting up user-level npm prefix..."
    npm config set prefix "$HOME/.npm-global"
    mkdir -p "$HOME/.npm-global/bin"
    export PATH="$HOME/.npm-global/bin:$PATH"

    # Force npm to reload configuration
    npm_prefix="$HOME/.npm-global"
    echo "[remote] npm prefix changed to: $npm_prefix"

    # Add to shell config if not already there
    if ! grep -q "/.npm-global/bin" "$HOME/.bashrc" 2>/dev/null; then
      echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> "$HOME/.bashrc"
      echo "[remote] Added npm global bin to .bashrc"
    fi
  fi

  echo "[remote] Attempting to install @devcontainers/cli@${DEVCONTAINER_CLI_VERSION}..."
  echo "[remote] Installing to: $npm_prefix/lib/node_modules"

  # Try npm install with the correct prefix explicitly set
  if ! npm install -g "@devcontainers/cli@${DEVCONTAINER_CLI_VERSION}" --prefix "$npm_prefix"; then
    echo "[remote] WARNING: Failed to upgrade devcontainer CLI"
    echo "[remote] The npm install command tried to write to: $(npm config get prefix)/lib/node_modules"
    echo "[remote] Current user $(whoami) may not have write permissions there"
    echo "[remote] Options to fix:"
    echo "[remote]   1. Configure npm to use user directory: npm config set prefix '~/.npm-global'"
    echo "[remote]   2. Use npx instead: npx @devcontainers/cli@${DEVCONTAINER_CLI_VERSION}"
    echo "[remote]   3. Set SKIP_DEVCONTAINER_UPGRADE=1 to skip this check"
    echo "[remote] Continuing with existing version..."
    return 0
  fi

  # After successful install, ensure devcontainer is in PATH
  # The new installation might be in ~/.npm-global/bin
  if [[ -x "$HOME/.npm-global/bin/devcontainer" ]]; then
    export PATH="$HOME/.npm-global/bin:$PATH"
    echo "[remote] Added ~/.npm-global/bin to PATH for this session"
  fi

  # Use hash to force shell to re-scan PATH
  hash -r

  # Now check the version using the full path if needed
  local devcontainer_cmd
  if [[ -x "$HOME/.npm-global/bin/devcontainer" ]]; then
    devcontainer_cmd="$HOME/.npm-global/bin/devcontainer"
  else
    devcontainer_cmd="devcontainer"
  fi

  if $devcontainer_cmd --version >/dev/null 2>&1; then
    local post_install
    post_install="$($devcontainer_cmd --version 2>/dev/null || true)"
    if [[ "$post_install" == "$DEVCONTAINER_CLI_VERSION" ]]; then
      echo "[remote] Installed devcontainer CLI $post_install."
    else
      echo "[remote] ERROR: devcontainer CLI still reports $post_install after install; check PATH/symlink to the new npm global bin." >&2
      exit 1
    fi
  else
    echo "[remote] ERROR: devcontainer CLI installation failed." >&2
    exit 1
  fi
}

[[ -d "$REPO_PATH" ]] || { echo "[remote] ERROR: Repo path not found."; exit 1; }
[[ -d "$KEY_CACHE" ]] || { echo "[remote] WARNING: Key cache $KEY_CACHE missing; create and rsync your .pub keys there."; mkdir -p "$KEY_CACHE"; }

echo "[remote] Removing previous sandbox..."
rm -rf "$SANDBOX_PATH"
mkdir -p "$SANDBOX_PATH"
mkdir -p "$WORKSPACE_PATH"

echo "[remote] Copying repo into sandbox..."
rsync -a --delete "$REPO_PATH"/ "$SANDBOX_PATH"/
if [[ "$WORKSPACE_PATH" != "$SANDBOX_PATH" ]]; then
  echo "[remote] Copying repo into workspace source..."
  rsync -a --delete "$REPO_PATH"/ "$WORKSPACE_PATH"/
fi

SSH_TARGET="$SANDBOX_PATH/$SSH_SUBDIR"
mkdir -p "$SSH_TARGET"

if compgen -G "$KEY_CACHE/*.pub" > /dev/null; then
  echo "[remote] Staging SSH keys:"
  for pub in "$KEY_CACHE"/*.pub; do
    base=$(basename "$pub")
    echo "  -> $pub"
    cp "$pub" "$SSH_TARGET/$base"
  done
else
  echo "[remote] ERROR: No *.pub files found in $KEY_CACHE."
  echo "         Copy your public key to $KEY_CACHE before rerunning."
  exit 1
fi

if [[ "$WORKSPACE_PATH" != "$SANDBOX_PATH" ]]; then
  WORKSPACE_SSH_TARGET="$WORKSPACE_PATH/$SSH_SUBDIR"
  mkdir -p "$WORKSPACE_SSH_TARGET"
  rsync -a --delete "$SSH_TARGET"/ "$WORKSPACE_SSH_TARGET"/
fi

echo "[remote] Ensuring baked images (base: $BASE_IMAGE, dev: $DEV_IMAGE)..."
pushd "$SANDBOX_PATH" >/dev/null
# Validate bake file before building
"$SCRIPT_DIR/check_docker_bake.sh" "$SANDBOX_PATH"
ensure_devcontainer_cli
# Validate devcontainer configuration syntax
"$SCRIPT_DIR/check_devcontainer_config.sh" "$SANDBOX_PATH"
# Build base if missing
if ! docker image inspect "$BASE_IMAGE" >/dev/null 2>&1; then
  echo "[remote] Base image $BASE_IMAGE missing; baking base..."
  docker buildx bake \
    -f "$SANDBOX_PATH/.devcontainer/docker-bake.hcl" \
    base \
    --set base.tags="$BASE_IMAGE" \
    --set '*.args.BASE_IMAGE'="$BASE_IMAGE" \
    --set '*.args.USERNAME'="$CONTAINER_USER" \
    --set '*.args.USER_UID'="$CONTAINER_UID" \
    --set '*.args.USER_GID'="$CONTAINER_GID"
else
  echo "[remote] Found base image $BASE_IMAGE."
fi

# Always rebuild devcontainer with current user/uid/gid
echo "[remote] Baking devcontainer image (user=${CONTAINER_USER}, uid=${CONTAINER_UID}, gid=${CONTAINER_GID})..."
docker buildx bake \
  -f "$SANDBOX_PATH/.devcontainer/docker-bake.hcl" \
  devcontainer \
  --set base.tags="$BASE_IMAGE" \
  --set devcontainer.tags="$DEV_IMAGE" \
  --set '*.args.BASE_IMAGE'="$BASE_IMAGE" \
  --set '*.args.USERNAME'="$CONTAINER_USER" \
  --set '*.args.USER_UID'="$CONTAINER_UID" \
  --set '*.args.USER_GID'="$CONTAINER_GID"
popd >/dev/null

export DEVCONTAINER_USER="${CONTAINER_USER}"
export DEVCONTAINER_UID="${CONTAINER_UID}"
export DEVCONTAINER_GID="${CONTAINER_GID}"
export DEVCONTAINER_WORKSPACE_PATH="${WORKSPACE_PATH}"
export REMOTE_WORKSPACE_PATH="${WORKSPACE_PATH}"
export REMOTE_SSH_SYNC_DIR="${KEY_CACHE}"

echo "[remote] Building container user ${CONTAINER_USER} (uid=${CONTAINER_UID}, gid=${CONTAINER_GID})"

echo "[remote] Running devcontainer up (SSH port: $DEVCONTAINER_SSH_PORT)..."

# Generate override config for port mapping if using non-default port
OVERRIDE_CONFIG=""
OVERRIDE_CONFIG_FILE=""
if [[ "$DEVCONTAINER_SSH_PORT" != "9222" ]]; then
  # Read the original devcontainer.json and patch the appPort
  OVERRIDE_CONFIG_FILE=$(mktemp --suffix=.json)
  ORIGINAL_CONFIG="$SANDBOX_PATH/.devcontainer/devcontainer.json"

  # Use jq to merge the appPort into the existing config
  if command -v jq >/dev/null 2>&1; then
    jq --arg port "127.0.0.1:${DEVCONTAINER_SSH_PORT}:2222" \
       '.appPort = [$port]' \
       "$ORIGINAL_CONFIG" > "$OVERRIDE_CONFIG_FILE"
    OVERRIDE_CONFIG="--override-config $OVERRIDE_CONFIG_FILE"
    echo "[remote] Using port override: $DEVCONTAINER_SSH_PORT (config: $OVERRIDE_CONFIG_FILE)"
  else
    echo "[remote] WARNING: jq not available, using default port 9222"
    DEVCONTAINER_SSH_PORT=9222
  fi
fi

# shellcheck disable=SC2086
devcontainer up \
  --workspace-folder "$SANDBOX_PATH" \
  --remove-existing-container \
  --build-no-cache \
  $OVERRIDE_CONFIG

# Clean up temp file
if [[ -n "$OVERRIDE_CONFIG_FILE" ]] && [[ -f "$OVERRIDE_CONFIG_FILE" ]]; then
  rm -f "$OVERRIDE_CONFIG_FILE"
fi

CONTAINER_ID=$(docker ps --filter "label=devcontainer.local_folder=${SANDBOX_PATH}" -q | head -n1)
if [[ -n "$CONTAINER_ID" ]]; then
  echo "[remote] Container $CONTAINER_ID online. Inspecting filesystem (sanity check)..."
docker exec "$CONTAINER_ID" sh -c 'echo "--- /tmp ---"; ls -al /tmp | head'
docker exec "$CONTAINER_ID" sh -c 'echo "--- workspace (top level) ---"; ls -al "$HOME/workspace" | head'
docker exec "$CONTAINER_ID" sh -c 'echo "--- LLVM packages list ---"; if [ -f /opt/llvm-packages-21.txt ]; then head /opt/llvm-packages-21.txt; else echo "No /opt/llvm-packages-21.txt"; fi'
  echo "[remote] docker ps (filtered for this devcontainer):"
  docker ps --filter "label=devcontainer.local_folder=${SANDBOX_PATH}" --format 'table {{.ID}}\t{{.Status}}\t{{.Ports}}'
  echo "[remote] sshd inside container:"
  docker exec "$CONTAINER_ID" sh -c 'ps -ef | grep "[s]shd" || true'
  # SSH connectivity check if a private key is available
  SSH_TEST_KEY="${KEY_CACHE}/id_ed25519"
  if [[ -f "$SSH_TEST_KEY" ]]; then
    echo "[remote] Testing SSH into container on port $DEVCONTAINER_SSH_PORT..."
    if ssh -i "$SSH_TEST_KEY" -o StrictHostKeyChecking=no -o BatchMode=yes -p "$DEVCONTAINER_SSH_PORT" "${CONTAINER_USER}@localhost" exit >/dev/null 2>&1; then
      echo "[remote] SSH test succeeded using ${SSH_TEST_KEY}."
    else
      echo "[remote] WARNING: SSH test failed using ${SSH_TEST_KEY}. Check authorized_keys and port mapping."
    fi
  else
    echo "[remote] WARNING: No ${SSH_TEST_KEY} found for SSH test."
  fi
else
  echo "[remote] WARNING: unable to locate container for inspection."
fi

echo "[remote] Devcontainer ready. Workspace: $SANDBOX_PATH"
