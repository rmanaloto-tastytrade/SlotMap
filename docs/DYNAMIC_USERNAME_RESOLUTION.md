# Dynamic Username Resolution Documentation

**Date:** 2025-01-23
**Status:** ✅ Implemented
**Purpose:** Ensure no hardcoded usernames exist in the deployment system

---

## Overview

The SlotMap devcontainer deployment system now uses dynamic username resolution throughout, eliminating all hardcoded usernames. This ensures the system works correctly regardless of the actual username on the remote host.

---

## Username Resolution Flow

### 1. Deploy Script (`scripts/deploy_remote_devcontainer.sh`)

**Resolution Order:**
1. **Command-line flag**: `--remote-user <username>` (highest priority)
2. **Git config**: `git config --get slotmap.remoteUser`
3. **Local user**: Falls back to current user running the script

```bash
# Line 34: Starts empty
REMOTE_USER=""  # Will be dynamically determined

# Lines 85-94: Dynamic resolution logic
CONFIG_REMOTE_USER="$(git config --get slotmap.remoteUser || true)"
if [[ -z "$REMOTE_USER" ]]; then
  if [[ -n "$CONFIG_REMOTE_USER" ]]; then
    REMOTE_USER="$CONFIG_REMOTE_USER"
  else
    REMOTE_USER="$LOCAL_USER"  # Current user
  fi
fi
```

### 2. Test Script (`scripts/test_devcontainer_ssh.sh`)

**Resolution Order:**
1. **Command-line flag**: `--user <username>` (highest priority)
2. **Git config**: `git config --get slotmap.remoteUser`
3. **Local user**: Falls back to current user, stripping domain if present

```bash
# Line 24: Starts empty
USER_NAME=""  # Will be dynamically determined

# Lines 43-54: Dynamic resolution logic
if [[ -z "$USER_NAME" ]]; then
  CONFIG_REMOTE_USER="$(git config --get slotmap.remoteUser 2>/dev/null || true)"
  if [[ -n "$CONFIG_REMOTE_USER" ]]; then
    USER_NAME="$CONFIG_REMOTE_USER"
  else
    USER_NAME="$(id -un)"
    USER_NAME="${USER_NAME%%@*}"  # Strip domain (user@domain -> user)
  fi
fi
```

### 3. Run Local Script (`scripts/run_local_devcontainer.sh`)

**Container User Resolution:**
```bash
# Line 24: Uses environment variable or current user
CONTAINER_USER=${CONTAINER_USER:-$(id -un)}

# Line 148: Exports for devcontainer
export DEVCONTAINER_USER="${CONTAINER_USER}"
```

### 4. Devcontainer Configuration (`.devcontainer/devcontainer.json`)

**Dynamic User References:**
```json
{
  "workspaceFolder": "/home/${env:DEVCONTAINER_USER}/workspace",
  "containerEnv": {
    "DEVCONTAINER_USER": "${localEnv:DEVCONTAINER_USER:-slotmap}"
  },
  "mounts": [
    "source=...,target=/home/${env:DEVCONTAINER_USER}/.ssh,..."
  ]
}
```

---

## Configuration Methods

### Method 1: Git Configuration (Recommended)

Set a persistent remote username for the project:
```bash
git config slotmap.remoteUser <your-username>
```

This will be used by all scripts automatically.

### Method 2: Environment Variables

Set environment variables before running scripts:
```bash
export CONTAINER_USER=myuser
./scripts/deploy_remote_devcontainer.sh
```

### Method 3: Command-Line Flags

Override username per execution:
```bash
# Deploy script
./scripts/deploy_remote_devcontainer.sh --remote-user myuser

# Test script
./scripts/test_devcontainer_ssh.sh --user myuser
```

---

## Username Propagation Chain

```mermaid
graph TD
    A[Local Machine User] -->|Default| B[deploy_remote_devcontainer.sh]
    B -->|REMOTE_USER| C[run_local_devcontainer.sh on Remote]
    C -->|CONTAINER_USER| D[Docker Build Args]
    D -->|USERNAME| E[Container User Creation]
    C -->|DEVCONTAINER_USER| F[Environment Export]
    F -->|env:DEVCONTAINER_USER| G[devcontainer.json]
    G -->|Container Paths| H[/home/USER/workspace]
```

---

## Verification Commands

### Check Current Configuration
```bash
# Check git config
git config --get slotmap.remoteUser

# Check current user
id -un

# Check what will be used (dry run)
./scripts/deploy_remote_devcontainer.sh --help
```

### Test Dynamic Resolution
```bash
# Test with default (current user)
./scripts/test_devcontainer_ssh.sh

# Test with git config
git config slotmap.remoteUser testuser
./scripts/test_devcontainer_ssh.sh

# Test with explicit flag
./scripts/test_devcontainer_ssh.sh --user anotheruser
```

---

## Important Notes

1. **No Hardcoded Usernames**: All references to specific usernames have been removed from scripts
2. **Documentation Examples**: Documentation files may still contain example usernames for clarity
3. **Backward Compatibility**: The `--remote-user` and `--user` flags maintain backward compatibility
4. **Default Behavior**: Without configuration, scripts use the current user's username
5. **Domain Stripping**: Email-style usernames (user@domain) are automatically stripped to just the username

---

## Migration from Hardcoded Username

If you were previously using the hardcoded username "rmanaloto", you can:

1. **Do nothing**: If your actual username matches
2. **Configure git**: `git config slotmap.remoteUser rmanaloto`
3. **Use flags**: Add `--remote-user rmanaloto` to scripts

---

## Benefits

1. **Flexibility**: Works with any username without modification
2. **Team Collaboration**: Different team members can use their own usernames
3. **Security**: No assumptions about user identity
4. **Maintainability**: No need to update scripts for different environments

---

## Troubleshooting

### Issue: Wrong username being used
**Solution**: Check resolution order and set explicitly via git config or flags

### Issue: Container permissions mismatch
**Solution**: Ensure CONTAINER_UID/GID match the remote user's actual UID/GID

### Issue: SSH key authentication fails
**Solution**: Verify the correct user's SSH keys are being used (check SSH_KEY_SYNC_PLAN.md)

---

## Related Documentation

- [SSH Key Audit](SSH_KEY_AUDIT.md) - SSH key management details
- [SSH Key Sync Plan](SSH_KEY_SYNC_PLAN.md) - SSH key synchronization strategy
- [Refactoring Roadmap](REFACTORING_ROADMAP.md) - Security improvements timeline