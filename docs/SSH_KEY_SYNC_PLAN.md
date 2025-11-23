# SSH Key Sync Implementation Plan

**Date:** 2025-01-23
**Objective:** Fix SSH key confusion and implement clean user separation
**Priority:** HIGH - Security and clarity issue

---

## Quick Fix (5 minutes)

### Disable Mac SSH Sync

**File:** `scripts/deploy_remote_devcontainer.sh`
**Line:** 42

```bash
# BEFORE (current):
SYNC_MAC_SSH="${SYNC_MAC_SSH:-1}"

# AFTER (proposed):
SYNC_MAC_SSH="${SYNC_MAC_SSH:-0}"  # Disabled by default
```

**Rationale:** The remote user (rmanaloto) should use their own SSH keys, not the Mac user's keys.

---

## Complete Solution

### Step 1: Verify Remote User Has SSH Keys

```bash
# Check if rmanaloto has SSH keys on c0802s4.ny5
ssh rmanaloto@c0802s4.ny5 << 'EOF'
echo "Checking for existing SSH keys..."
ls -la ~/.ssh/
if [ -f ~/.ssh/id_ed25519 ]; then
  echo "✅ Found existing ed25519 key"
else
  echo "❌ No ed25519 key found"
  echo "To generate: ssh-keygen -t ed25519 -C 'rmanaloto@c0802s4.ny5'"
fi
EOF
```

### Step 2: Update Script Defaults

**File:** `scripts/deploy_remote_devcontainer.sh`

#### Change 1: Disable Mac SSH sync
```bash
# Line 42
SYNC_MAC_SSH="${SYNC_MAC_SSH:-0}"  # Default: Don't sync Mac SSH
```

#### Change 2: Add clear documentation
```bash
# Line 119 (before the if statement)
# NOTE: Mac SSH sync is typically NOT needed if the remote user has their own keys.
# The remote user (rmanaloto) should manage their own SSH keys for container access.
# Only enable this if you specifically need Mac user's keys in the container.
```

### Step 3: Update devcontainer.json Mount

**Current Issue:** The bind mount uses Mac-synced keys

**File:** `.devcontainer/devcontainer.json`
**Line:** 22

```json
// CURRENT (uses synced Mac keys):
"source=${localEnv:REMOTE_SSH_SYNC_DIR},target=/home/${env:DEVCONTAINER_USER}/.ssh,type=bind,consistency=cached"

// OPTION 1: Use remote user's own .ssh directory
"source=/home/rmanaloto/.ssh,target=/home/${env:DEVCONTAINER_USER}/.ssh,type=bind,consistency=cached,readonly"

// OPTION 2: Remove bind mount entirely (use agent forwarding)
// Just remove line 22 completely
```

### Step 4: Setup Container Access

#### Option A: Remote User's Keys (Recommended)

1. **Generate key on remote (if needed):**
   ```bash
   ssh rmanaloto@c0802s4.ny5
   ssh-keygen -t ed25519 -C "rmanaloto@c0802s4.ny5"
   ```

2. **Add to container's authorized_keys:**
   ```bash
   # This happens automatically via bind mount
   ```

3. **Test access:**
   ```bash
   ssh -i ~/.ssh/id_ed25519 -p 9222 rmanaloto@c0802s4.ny5
   ```

#### Option B: SSH Agent Forwarding (Cleanest)

1. **Start agent on Mac:**
   ```bash
   eval "$(ssh-agent -s)"
   ssh-add ~/.ssh/id_ed25519
   ```

2. **Connect with forwarding:**
   ```bash
   ssh -A rmanaloto@c0802s4.ny5
   ```

3. **Access container:**
   ```bash
   ssh -A -p 9222 rmanaloto@c0802s4.ny5
   ```

---

## Files to Update

### 1. scripts/deploy_remote_devcontainer.sh
- [ ] Line 42: Change default to `SYNC_MAC_SSH="${SYNC_MAC_SSH:-0}"`
- [ ] Line 119: Add documentation comment
- [ ] Lines 167-170: Review if key copying is still needed

### 2. .devcontainer/devcontainer.json
- [ ] Line 22: Change mount source or remove entirely

### 3. Documentation Updates
- [ ] README.md: Clarify SSH access methods
- [ ] TEST_BRANCH_README.md: Update test procedures
- [ ] docs/REFACTORING_ROADMAP.md: Add as Milestone 1.4
- [ ] docs/AI_AGENT_CONTEXT.md: Update commands

---

## Testing Matrix

| Scenario | SYNC_MAC_SSH | Mount | Expected Result |
|----------|--------------|-------|-----------------|
| Remote user keys | 0 | /home/rmanaloto/.ssh | ✅ Works with rmanaloto's keys |
| Agent forwarding | 0 | None | ✅ Works with -A flag |
| Mac sync (legacy) | 1 | ~/devcontainers/ssh_keys | ⚠️ Works but not recommended |

---

## Validation Commands

### Test 1: Deploy without Mac SSH sync
```bash
cd /Users/ray.manaloto@tastytrade.com/dev/github/SergeyMakeev/SlotMap-security-test
SYNC_MAC_SSH=0 ./scripts/deploy_remote_devcontainer.sh
```

### Test 2: Verify what's in container
```bash
ssh -p 9222 rmanaloto@c0802s4.ny5 'ls -la ~/.ssh/'
# Should show remote user's keys, not Mac user's
```

### Test 3: Test GitHub access
```bash
ssh -A -p 9222 rmanaloto@c0802s4.ny5 'ssh -T git@github.com'
# Should work with agent forwarding
```

---

## Rollback Plan

If issues occur, revert to Mac SSH sync:
```bash
SYNC_MAC_SSH=1 ./scripts/deploy_remote_devcontainer.sh
```

---

## Benefits After Implementation

1. **Clear Separation:** No confusion about which user's keys are being used
2. **Better Security:** Keys stay where they belong
3. **Simpler Flow:** Remote user manages their own access
4. **Agent Forwarding:** Most secure option available

---

## Timeline

- **Immediate (5 min):** Change default to SYNC_MAC_SSH=0
- **Today:** Test with remote user's keys
- **Tomorrow:** Update documentation
- **This week:** Remove Mac SSH sync code entirely