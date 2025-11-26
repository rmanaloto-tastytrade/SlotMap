#!/usr/bin/env bash
set -euo pipefail

CURRENT_USER="${DEVCONTAINER_USER:-$(id -un)}"
CURRENT_GROUP="$(id -gn "$CURRENT_USER" 2>/dev/null || id -gn)"
WORKSPACE_DIR="${WORKSPACE_FOLDER:-/home/${CURRENT_USER}/workspace}"

if command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
  sudo chown -R "${CURRENT_USER}:${CURRENT_GROUP}" /opt/vcpkg /opt/vcpkg/downloads "${WORKSPACE_DIR}" || true
else
  echo "[post_create] Skipping chown (sudo password required or unavailable)."
fi

echo "[post_create] Validating toolchain configuration..."

# Validate compilers
if ! command -v clang++-21 >/dev/null 2>&1; then
  echo "[post_create] ERROR: clang++-21 not found in PATH" >&2
  exit 1
fi
echo "[post_create] ✓ clang++-21 found"

# Validate linker (mold)
if ! command -v mold >/dev/null 2>&1 && ! command -v ld.mold >/dev/null 2>&1; then
  echo "[post_create] WARNING: mold linker not found, falling back to LLD"
else
  echo "[post_create] ✓ mold linker found: $(which mold 2>/dev/null || which ld.mold)"
fi

# Validate LLD (fallback linker, also required for LTO)
if ! command -v ld.lld-21 >/dev/null 2>&1; then
  echo "[post_create] WARNING: ld.lld-21 not found (needed for LTO)"
else
  echo "[post_create] ✓ ld.lld-21 found"
fi

# Validate LLVM binutils
LLVM_TOOLS="llvm-ar-21 llvm-nm-21 llvm-ranlib-21 llvm-objdump-21 llvm-strip-21"
for tool in $LLVM_TOOLS; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "[post_create] WARNING: $tool not found"
  fi
done
echo "[post_create] ✓ LLVM binutils validated"

# Validate update-alternatives configuration
echo "[post_create] Checking update-alternatives configuration..."
CC_LINK=$(update-alternatives --query cc 2>/dev/null | grep "Value:" | awk '{print $2}' || echo "unknown")
CXX_LINK=$(update-alternatives --query c++ 2>/dev/null | grep "Value:" | awk '{print $2}' || echo "unknown")
LD_LINK=$(update-alternatives --query ld 2>/dev/null | grep "Value:" | awk '{print $2}' || echo "unknown")
AR_LINK=$(update-alternatives --query ar 2>/dev/null | grep "Value:" | awk '{print $2}' || echo "unknown")

echo "[post_create]   cc  -> $CC_LINK"
echo "[post_create]   c++ -> $CXX_LINK"
echo "[post_create]   ld  -> $LD_LINK"
echo "[post_create]   ar  -> $AR_LINK"

# Warn if alternatives don't point to expected tools
if [[ "$CC_LINK" != *"clang"* ]]; then
  echo "[post_create] WARNING: cc doesn't point to clang ($CC_LINK)"
fi
if [[ "$LD_LINK" != *"mold"* ]] && [[ "$LD_LINK" != *"lld"* ]]; then
  echo "[post_create] WARNING: ld doesn't point to mold or lld ($LD_LINK)"
fi

echo "[post_create] Toolchain validation complete"

SSH_SOURCE="${WORKSPACE_DIR}/.devcontainer/ssh"
SSH_TARGET="$HOME/.ssh"

# SAFETY: Never overwrite private keys, only work with public keys and config
echo "[post_create] SSH Safety Check: Ensuring no private keys are modified"

# Check for existing private keys and protect them
if ls "$SSH_TARGET"/id_* 2>/dev/null | grep -v '\.pub$' > /dev/null; then
  echo "[post_create] WARNING: Private keys detected in $SSH_TARGET - will not modify them"
fi

if compgen -G "$SSH_SOURCE/"'*.pub' > /dev/null; then
  mkdir -p "$SSH_TARGET"
  chmod 700 "$SSH_TARGET"

  # SAFETY: Backup existing authorized_keys before modification
  if [[ -f "$SSH_TARGET/authorized_keys" ]]; then
    cp "$SSH_TARGET/authorized_keys" "$SSH_TARGET/authorized_keys.backup.$(date +%Y%m%d-%H%M%S)"
    echo "[post_create] Backed up existing authorized_keys"
  fi

  cat "$SSH_SOURCE/"*.pub > "$SSH_TARGET/authorized_keys"
  chmod 600 "$SSH_TARGET/authorized_keys"
  echo "[post_create] Installed authorized_keys from $SSH_SOURCE (only public keys)"
else
  echo "[post_create] WARNING: No public keys found under $SSH_SOURCE"
fi

# Sanitize macOS SSH config (UseKeychain is unsupported on Linux)
SSH_CONFIG_FILE="$SSH_TARGET/config"
if [[ -f "$SSH_CONFIG_FILE" ]] && grep -q "UseKeychain" "$SSH_CONFIG_FILE"; then
  # SAFETY: Create timestamped backup before modifying config
  BACKUP_FILE="$SSH_TARGET/config.backup.$(date +%Y%m%d-%H%M%S)"
  cp "$SSH_CONFIG_FILE" "$BACKUP_FILE"
  echo "[post_create] Created safety backup at $BACKUP_FILE"

  # Also keep the macOS-specific backup
  cp "$SSH_CONFIG_FILE" "$SSH_TARGET/config.macbak"
  grep -v "UseKeychain" "$SSH_TARGET/config.macbak" > "$SSH_CONFIG_FILE"
  chmod 600 "$SSH_CONFIG_FILE"
  echo "[post_create] Filtered UseKeychain from ~/.ssh/config (backups at config.macbak and $BACKUP_FILE)"
fi

# Force GitHub SSH over 443 inside the container (port 22 is often blocked on remote hosts).
# See: https://docs.github.com/en/authentication/troubleshooting-ssh/using-ssh-over-the-https-port
{
  echo ""
  echo "# Added by post_create.sh for devcontainer: use GitHub SSH over 443"
  echo "Host github.com"
  echo "  Hostname ssh.github.com"
  echo "  Port 443"
  echo "  User git"
} >> "$SSH_CONFIG_FILE"
chmod 600 "$SSH_CONFIG_FILE"

BUILD_DIR="${WORKSPACE_DIR}/build/clang-debug"
CACHE_FILE="${BUILD_DIR}/CMakeCache.txt"

if [[ -f "$CACHE_FILE" ]]; then
  if ! grep -q "CMAKE_HOME_DIRECTORY:INTERNAL=${WORKSPACE_DIR}" "$CACHE_FILE"; then
    echo "[post_create] Removing stale CMake cache at $BUILD_DIR (workspace path changed)."
    rm -rf "$BUILD_DIR"
  fi
fi

cd "$WORKSPACE_DIR"
cmake --preset clang-debug
