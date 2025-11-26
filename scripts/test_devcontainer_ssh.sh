#!/usr/bin/env bash
set -euo pipefail

# Verbose SSH connectivity test to the devcontainer exposed on a remote host.
# Configuration: Set DEVCONTAINER_REMOTE_HOST in config/env/devcontainer.env or pass --host

usage() {
  cat <<'USAGE'
Usage: scripts/test_devcontainer_ssh.sh [options]

Options:
  --host <hostname>        Remote host (required, or set DEVCONTAINER_REMOTE_HOST)
  --port <port>            Remote SSH port (default: 9222 or DEVCONTAINER_SSH_PORT)
  --user <username>        SSH username (default: git config or current user)
  --key <path>             Private key path (default: ~/.ssh/id_ed25519)
  --known-hosts <path>     Known hosts file (default: ~/.ssh/known_hosts)
  --clear-known-host       Remove existing host key entry for [host]:[port] before testing
  -h, --help               Show this help
USAGE
}

# Load local config file if present
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_ENV_FILE="${CONFIG_ENV_FILE:-$REPO_ROOT/config/env/devcontainer.env}"
if [[ -f "$CONFIG_ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_ENV_FILE"
fi

# No hardcoded default - use config file or CLI
HOST="${DEVCONTAINER_REMOTE_HOST:-}"
PORT="${DEVCONTAINER_SSH_PORT:-9222}"
USER_NAME=""  # Will be dynamically determined or can be overridden with --user
KEY_PATH="$HOME/.ssh/id_ed25519"
KNOWN_HOSTS_FILE="$HOME/.ssh/known_hosts"
CLEAR_KNOWN_HOST=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) HOST="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    --user) USER_NAME="$2"; shift 2 ;;
    --key) KEY_PATH="$2"; shift 2 ;;
    --known-hosts) KNOWN_HOSTS_FILE="$2"; shift 2 ;;
    --clear-known-host) CLEAR_KNOWN_HOST=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

# Validate required HOST
if [[ -z "$HOST" ]]; then
  echo "[ssh-test] ERROR: Remote host is required." >&2
  echo "[ssh-test] Either:" >&2
  echo "  1. Create config/env/devcontainer.env with DEVCONTAINER_REMOTE_HOST=your.host" >&2
  echo "  2. Pass --host your.host on command line" >&2
  exit 1
fi

# Dynamically determine username if not provided
if [[ -z "$USER_NAME" ]]; then
  # Try git config first
  CONFIG_REMOTE_USER="$(git config --get slotmap.remoteUser 2>/dev/null || true)"
  if [[ -n "$CONFIG_REMOTE_USER" ]]; then
    USER_NAME="$CONFIG_REMOTE_USER"
  else
    # Fall back to current user
    USER_NAME="$(id -un)"
    # Strip domain if present (e.g., user@domain -> user)
    USER_NAME="${USER_NAME%%@*}"
  fi
fi

[[ -f "$KEY_PATH" ]] || { echo "[ssh-test] ERROR: key not found: $KEY_PATH" >&2; exit 1; }

echo "[ssh-test] Host: $HOST"
echo "[ssh-test] Port: $PORT"
echo "[ssh-test] User: $USER_NAME"
echo "[ssh-test] Key : $KEY_PATH"
echo "[ssh-test] Known hosts file: $KNOWN_HOSTS_FILE"

echo "[ssh-test] Key fingerprint:"
ssh-keygen -lf "$KEY_PATH" || true

if [[ "$CLEAR_KNOWN_HOST" -eq 1 ]]; then
  echo "[ssh-test] Clearing existing host key for [$HOST]:$PORT from $KNOWN_HOSTS_FILE"
  CANON_HOST=$(ssh -G "$HOST" 2>/dev/null | awk '/^hostname / {print $2}' | head -n1)
  [[ -z "$CANON_HOST" ]] && CANON_HOST="$HOST"
  ssh-keygen -R "[$HOST]:$PORT" -f "$KNOWN_HOSTS_FILE" >/dev/null 2>&1 || true
  ssh-keygen -R "[$CANON_HOST]:$PORT" -f "$KNOWN_HOSTS_FILE" >/dev/null 2>&1 || true
fi

SSH_CMD=(ssh -vvv
  -i "$KEY_PATH"
  -o IdentitiesOnly=yes
  -o UserKnownHostsFile="$KNOWN_HOSTS_FILE"
  -o StrictHostKeyChecking=no
  -o ConnectTimeout=10
  -p "$PORT"
  "${USER_NAME}@${HOST}"
  "echo SSH_OK")

echo "[ssh-test] Executing: ${SSH_CMD[*]}"
if "${SSH_CMD[@]}"; then
  echo "[ssh-test] SUCCESS"
else
  echo "[ssh-test] FAILED" >&2
  exit 1
fi

# Additional validation inside the container (tools, sudo, workspace perms, GitHub SSH)
REMOTE_CHECK_CMD=$(cat <<'REMOTE'
failed=0
echo "[ssh-remote] whoami: $(whoami)"
echo "[ssh-remote] id: $(id)"
echo "[ssh-remote] pwd: $(pwd)"
if test -w "$HOME/workspace"; then
  echo "[ssh-remote] workspace writable: yes"
else
  echo "[ssh-remote] workspace writable: NO"; failed=1
fi
if sudo -n true >/dev/null 2>&1; then
  echo "[ssh-remote] sudo -n true: OK"
else
  echo "[ssh-remote] sudo -n true: FAILED"; failed=1
fi
for bin in clang++-21 ninja cmake vcpkg; do
  if command -v "$bin" >/dev/null 2>&1; then
    echo "[ssh-remote] found $bin: $(command -v "$bin")"
  else
    echo "[ssh-remote] MISSING $bin"; failed=1
  fi
done
# mrdocs may not be on PATH; check explicit location
if command -v mrdocs >/dev/null 2>&1; then
  echo "[ssh-remote] found mrdocs: $(command -v mrdocs)"
elif [[ -x /opt/mrdocs/bin/mrdocs ]]; then
  echo "[ssh-remote] found mrdocs at /opt/mrdocs/bin/mrdocs (not in PATH)"
else
  echo "[ssh-remote] MISSING mrdocs"; failed=1
fi
echo "[ssh-remote] Testing GitHub SSH access"
# Check if SSH agent is available (for security-conscious agent forwarding)
if ssh-add -l >/dev/null 2>&1; then
  echo "[ssh-remote] SSH agent detected, using agent forwarding for GitHub auth"
  # Use agent (no -i flag, no private key needed)
  ssh -F /dev/null -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ConnectTimeout=10 -T git@github.com 2>&1 | head -3
  if [ $? -eq 0 ] || [ $? -eq 1 ]; then
    echo "[ssh-remote] GitHub SSH OK via agent"
  else
    echo "[ssh-remote] GitHub SSH via agent failed"
    failed=1
  fi
else
  echo "[ssh-remote] WARNING: No SSH agent available"
  echo "[ssh-remote] INFO: For secure GitHub access, use SSH agent forwarding:"
  echo "[ssh-remote]   1. On Mac: eval \"\$(ssh-agent -s)\" && ssh-add ~/.ssh/id_ed25519"
  echo "[ssh-remote]   2. Connect with: ssh -A -p $PORT $USER_NAME@$HOST"
  echo "[ssh-remote] Skipping GitHub SSH test (agent forwarding not configured)"
fi
exit $failed
REMOTE
)

SSH_CMD_REMOTE=(ssh
  -i "$KEY_PATH"
  -o IdentitiesOnly=yes
  -o UserKnownHostsFile=/dev/null
  -o StrictHostKeyChecking=no
  -o ConnectTimeout=15
  -p "$PORT"
  "${USER_NAME}@${HOST}"
  "$REMOTE_CHECK_CMD")

echo "[ssh-test] Executing remote validation command..."
if "${SSH_CMD_REMOTE[@]}"; then
  echo "[ssh-test] Remote validation completed."
else
  echo "[ssh-test] Remote validation failed." >&2
  exit 1
fi
