# Devcontainer Branch Comparison Analysis

**Comparing:** `security-fixes-phase1` (current) vs `modernization.20251118`

**Date:** 2025-11-25 (Updated)

---

## Executive Summary

The `modernization.20251118` branch introduces significant security, usability, and architectural improvements:

1. **Security**: SSH agent socket forwarding instead of key file mounting + localhost-only port binding
2. **Configuration**: Gitignored local config file pattern (`config/env/devcontainer.env`) with example template
3. **Portability**: Complete removal of hardcoded hostnames/usernames with CI guardrail
4. **SSH Config Generator**: New script to generate dedicated SSH config with ProxyJump
5. **Documentation**: Comprehensive SSH options and key management docs
6. **Simplification**: Massive cleanup - removed ~2000+ lines of unused code/docs

---

## Architecture Overview: Modernization Branch

### Build Workflow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              MacBook (Local)                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│  1. User creates config/env/devcontainer.env (one-time, gitignored)         │
│     - DEVCONTAINER_REMOTE_HOST=myhost.example.com                           │
│     - DEVCONTAINER_REMOTE_USER=myuser                                       │
│     - DEVCONTAINER_SSH_PORT=9222                                            │
│                                                                             │
│  2. User runs: ./scripts/deploy_remote_devcontainer.sh                      │
│     - Script sources config/env/devcontainer.env automatically              │
│     - No command-line flags needed!                                         │
│                                                                             │
│  3. Copies ONLY public key to remote (private keys NEVER leave Mac)         │
│                                                                             │
│  4. SSHs to remote host and triggers run_local_devcontainer.sh              │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ SSH (port 22)
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Remote Linux Host                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│  5. run_local_devcontainer.sh executes:                                     │
│     a. Loads config/env/devcontainer.env (if present)                       │
│     b. Validates docker-bake.hcl syntax                                     │
│     c. Validates devcontainer.json syntax                                   │
│     d. Creates sandbox copy of repo                                         │
│     e. Stages ONLY public keys for authorized_keys                          │
│     f. Builds base image (if missing): docker buildx bake base              │
│     g. Builds devcontainer image: docker buildx bake devcontainer           │
│     h. Runs: devcontainer up --workspace-folder $SANDBOX_PATH               │
│                                                                             │
│  Directory Layout:                                                          │
│    ~/dev/github/SlotMap           - Clean git clone (source of truth)       │
│    ~/dev/devcontainers/SlotMap    - Sandbox (recreated each deploy)         │
│    ~/dev/devcontainers/workspace  - Workspace bind-mounted into container   │
│    ~/.ssh/*.pub                   - Public keys for container auth          │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ Docker
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                            Docker Container                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│  Image: devcontainer:local (built via docker-bake.hcl)                      │
│                                                                             │
│  Features:                                                                  │
│    - ghcr.io/devcontainers/features/sshd:1 (SSH server on port 2222)        │
│                                                                             │
│  Mounts:                                                                    │
│    - slotmap-vcpkg volume → /opt/vcpkg/downloads                            │
│    - SSH_AUTH_SOCK socket → /tmp/ssh-agent.socket (agent forwarding)        │
│                                                                             │
│  Port Mapping (LOCALHOST ONLY - more secure):                               │
│    - Host 127.0.0.1:${DEVCONTAINER_SSH_PORT:-9222} → Container 2222         │
│                                                                             │
│  Post-Create:                                                               │
│    - Installs authorized_keys from staged public keys                       │
│    - Filters macOS SSH config (removes UseKeychain)                         │
│    - Configures GitHub SSH over port 443                                    │
│    - Detects stale CMake cache and removes if workspace path changed        │
│    - Runs cmake --preset clang-debug                                        │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ SSH via ProxyJump or Tunnel
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         MacBook Connection                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│  Option 1: Generate dedicated SSH config (recommended)                      │
│    ./scripts/generate_cpp_devcontainer_ssh_config.sh                        │
│    ssh -F ~/.ssh/cpp-devcontainer.conf cpp-devcontainer                     │
│                                                                             │
│  Option 2: Manual ProxyJump                                                 │
│    ssh -J user@host -p 9222 user@127.0.0.1                                  │
│                                                                             │
│  Option 3: SSH tunnel                                                       │
│    ssh -L 9222:127.0.0.1:9222 user@host -N -f                               │
│    ssh -p 9222 user@localhost                                               │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Docker Build Pipeline

```
docker-bake.hcl orchestrates multi-stage Dockerfile builds:

┌──────────────┐
│    base      │ ◄── Ubuntu 24.04 + gcc-14/clang-21 + perf + git/cmake/ninja
└──────┬───────┘
       │
       ├────────┬────────┬────────┬────────┬────────┬────────┬─── ... ───┐
       ▼        ▼        ▼        ▼        ▼        ▼        ▼           ▼
┌──────────┐┌──────────┐┌──────────┐┌──────────┐┌──────────┐┌──────────┐┌────────┐
│clang_p296││node_mmdc ││   mold   ││  gh_cli  ││  ccache  ││ sccache  ││  ...   │
└────┬─────┘└────┬─────┘└────┬─────┘└────┬─────┘└────┬─────┘└────┬─────┘└───┬────┘
     │           │           │           │           │           │          │
     └───────────┴───────────┴───────────┴───────────┴───────────┴──────────┘
                                         │
                                         ▼
                                ┌────────────────┐
                                │  tools_merge   │ ◄── Combines all tool stages
                                └───────┬────────┘
                                        │
                                        ▼
                                ┌────────────────┐
                                │  devcontainer  │ ◄── Final image with user setup
                                └────────────────┘

Tool stages (parallel builds):
  clang_p2996, node_mermaid, mold, gh_cli, ccache, sccache, ripgrep,
  cppcheck, valgrind, python_tools, pixi, iwyu, mrdocs, jq, awscli
```

---

## Feature Comparison Table

### Configuration & Environment

| Feature | `security-fixes-phase1` (Current) | `modernization.20251118` | Action |
|---------|-----------------------------------|--------------------------|--------|
| Local config file | None | `config/env/devcontainer.env` (gitignored) | **Adopt** |
| Config example template | None | `config/env/devcontainer.env.example` | **Adopt** |
| Config README | None | `config/env/README.md` | **Adopt** |
| Config file loading | N/A | All scripts source env file if present | **Adopt** |
| Hardcoded hostname | `c0802s4.ny5` in deploy script | Removed, uses env vars only | **Adopt** |
| Hardcoded refs guard (local) | None | `scripts/check_hardcoded_refs.sh` | **Adopt** |
| Hardcoded refs guard (CI) | None | `.github/workflows/hardcoded-guard.yml` | **Adopt** |

### SSH Security

| Feature | `security-fixes-phase1` (Current) | `modernization.20251118` | Action |
|---------|-----------------------------------|--------------------------|--------|
| SSH key sync default | `SYNC_MAC_SSH=0` (disabled) | `SYNC_MAC_SSH=0` (disabled) | Same |
| Container SSH access | Bind-mounts `REMOTE_SSH_SYNC_DIR` to `~/.ssh` | Bind-mounts `SSH_AUTH_SOCK` socket only | **Adopt** |
| Private keys in container | Potentially via bind mount | Never - only agent socket | **Adopt** |
| SSH port binding | `0.0.0.0:9222` (all interfaces) | `127.0.0.1:9222` (localhost only) | **Adopt** |
| SSH port config | Hardcoded `9222` in devcontainer.json | `${localEnv:DEVCONTAINER_SSH_PORT:-9222}` | **Adopt** |
| GitHub SSH port | Port 22 (often blocked) | Port 443 via ssh.github.com | **Adopt** |
| SSH config generator | None | `scripts/generate_cpp_devcontainer_ssh_config.sh` | **Adopt** |
| SSH options documentation | None | `docs/ssh-configurations.md` | **Adopt** |
| SSH key management docs | None | `docs/ssh-key-management-options.md` | **Adopt** |

### Build System

| Feature | `security-fixes-phase1` (Current) | `modernization.20251118` | Action |
|---------|-----------------------------------|--------------------------|--------|
| Docker Bake | Identical multi-stage pipeline | Identical multi-stage pipeline | Same |
| Base image caching | Yes | Yes | Same |
| devcontainer CLI version | Not pinned | `DEVCONTAINER_CLI_VERSION=0.80.2` | **Adopt** |
| Bake validation | `check_docker_bake.sh` | `check_docker_bake.sh` | Same |
| Config validation | `check_devcontainer_config.sh` | `check_devcontainer_config.sh` | Same |
| Mermaid diagrams | `.mmd` files only | `.mmd` + rendered `.png/.svg` | **Adopt** |
| Diagram rendering script | `generate_diagrams.sh` (111 lines) | `render_diagrams.sh` (70 lines) | **Adopt** |

### Post-Create Setup

| Feature | `security-fixes-phase1` (Current) | `modernization.20251118` | Action |
|---------|-----------------------------------|--------------------------|--------|
| authorized_keys setup | From synced keys | From staged public keys only | Same approach |
| macOS SSH config filter | None | Removes `UseKeychain` directive | **Adopt** |
| GitHub SSH config | None | Adds ssh.github.com:443 config | **Adopt** |
| Stale cache detection | None | Removes CMakeCache if workspace path changed | **Adopt** |
| Auto cmake configure | Yes | Yes | Same |

### Scripts

| Feature | `security-fixes-phase1` (Current) | `modernization.20251118` | Action |
|---------|-----------------------------------|--------------------------|--------|
| deploy_remote_devcontainer.sh | With hardcoded defaults | Fully parameterized, loads env file | **Adopt** |
| run_local_devcontainer.sh | ~200 lines | ~144 lines (simplified) | **Adopt** |
| test_devcontainer_ssh.sh | Has some hardcoded refs | Fully parameterized | **Adopt** |
| status_devcontainer.sh | Does not exist | Shows env, logs, command hints | **Adopt** |
| check_hardcoded_refs.sh | Does not exist | Guardrail script | **Adopt** |
| generate_cpp_devcontainer_ssh_config.sh | Does not exist | SSH config generator with ProxyJump | **Adopt** |
| Scheduler scripts | Present (~500 lines) | Removed | **Adopt** |
| update_tools_*.sh | Present (~400 lines) | Removed | **Adopt** |
| sync_gh_auth.sh | Present (~70 lines) | Removed | **Adopt** |

### devcontainer.json

| Feature | `security-fixes-phase1` (Current) | `modernization.20251118` | Action |
|---------|-----------------------------------|--------------------------|--------|
| SSH_AUTH_SOCK env var | Not set | Set to `/tmp/ssh-agent.socket` | **Adopt** |
| SSH socket mount | Not present | Mounts `${localEnv:SSH_AUTH_SOCK}` | **Adopt** |
| SSH keys mount | Mounts `REMOTE_SSH_SYNC_DIR` to `~/.ssh` | Removed (uses agent instead) | **Adopt** |
| SSH port binding | `-p 9222:2222` | `-p 127.0.0.1:${..}:2222` | **Adopt** |
| SSH port variable | Hardcoded `9222` | `${localEnv:DEVCONTAINER_SSH_PORT:-9222}` | **Adopt** |

### Documentation

| Feature | `security-fixes-phase1` (Current) | `modernization.20251118` | Action |
|---------|-----------------------------------|--------------------------|--------|
| CURRENT_WORKFLOW.md | Outdated | Completely rewritten (~200 lines) | **Adopt** |
| ssh-configurations.md | Does not exist | SSH options comparison (6 approaches) | **Adopt** |
| ssh-key-management-options.md | Does not exist | Key management tools comparison | **Adopt** |
| TODO.md | Does not exist | Next steps and context preservation | **Adopt** |
| Mermaid workflow diagrams | Some | New rendered diagrams with .png/.svg | **Adopt** |
| Scheduler docs | ~1400 lines across 5 files | Removed (unused) | **Adopt** |
| SSH key sync docs | ~640 lines across 3 files | Removed (replaced by new docs) | **Adopt** |

### .gitignore

| Feature | `security-fixes-phase1` (Current) | `modernization.20251118` | Action |
|---------|-----------------------------------|--------------------------|--------|
| config/env/devcontainer.env | Not listed | Listed (prevents secrets in git) | **Adopt** |
| Security patterns (*.pem, etc) | Yes (extensive) | Simplified | Review |

### Project Files

| Feature | `security-fixes-phase1` (Current) | `modernization.20251118` | Action |
|---------|-----------------------------------|--------------------------|--------|
| CMakeLists.txt | Full with benchmarks | Removed (different focus) | Keep ours |
| CMakePresets.json | Full with sanitizers | Different (simpler) | Keep ours |
| benchmarks/ | Present | Removed | Keep ours |
| .clang-tidy | Present | Removed | Keep ours |
| .iwyu.imp | Present | Removed | Keep ours |

---

## New Features in Modernization Branch

### 1. SSH Config Generator Script

**File:** `scripts/generate_cpp_devcontainer_ssh_config.sh`

Generates a dedicated SSH config file for connecting to the devcontainer with ProxyJump:

```bash
# Generate config from your devcontainer.env
./scripts/generate_cpp_devcontainer_ssh_config.sh

# Output: ~/.ssh/cpp-devcontainer.conf
# Contains:
#   Host cpp-devcontainer
#       HostName 127.0.0.1
#       Port 9222
#       User myuser
#       ProxyJump myuser@myhost.example.com
#       ForwardAgent yes
#       ...

# Connect with simple alias
ssh -F ~/.ssh/cpp-devcontainer.conf cpp-devcontainer
```

**Benefits:**
- No need to remember ProxyJump syntax
- Includes agent forwarding, keep-alive settings
- Resolves hostname via ssh -G for corporate DNS handling
- Separate from main ~/.ssh/config

### 2. Localhost-Only Port Binding

**Before (Current Branch):**
```json
"runArgs": ["-p", "9222:2222"]
```
Container SSH exposed on all network interfaces.

**After (Modernization Branch):**
```json
"runArgs": ["-p", "127.0.0.1:${localEnv:DEVCONTAINER_SSH_PORT:-9222}:2222"]
```
Container SSH only accessible via:
- ProxyJump through the remote host
- SSH tunnel from your Mac

**Security Impact:** Reduces attack surface - container SSH not directly exposed on network.

### 3. GitHub Actions CI Guard

**File:** `.github/workflows/hardcoded-guard.yml`

```yaml
name: Hardcoded Host/User Guard
on: [push, pull_request]
jobs:
  guard:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: scripts/check_hardcoded_refs.sh
```

**Purpose:** Fails CI if anyone commits personal hostnames/usernames to `.devcontainer/` or `scripts/`.

### 4. Comprehensive SSH Documentation

Two new docs explain SSH options:

**`docs/ssh-configurations.md`** - 6 approaches compared:
1. Host SSH agent bind (current default)
2. Agent forwarding from laptop
3. Host-resident deploy key
4. Public-key staging only
5. Mounting private keys (NOT recommended)
6. Cert-based access (Teleport)

**`docs/ssh-key-management-options.md`** - Tool comparison:
- Teleport (enterprise certs)
- ssh-key-sync / ssh-copy-id (lightweight)
- Unison/Syncthing (avoid for keys)
- ssh-key-authority (self-hosted)

### 5. Config Environment Template

**Files:**
- `config/env/README.md` - Usage instructions
- `config/env/devcontainer.env.example` - Template to copy

```bash
# One-time setup
cp config/env/devcontainer.env.example config/env/devcontainer.env
# Edit with your values
vim config/env/devcontainer.env
```

---

## Files Removed in Modernization Branch

### Scripts Removed (~980 lines)

| Script | Lines | Why Removed |
|--------|-------|-------------|
| `scripts/schedulers/README.md` | 128 | Unused scheduler feature |
| `scripts/schedulers/com.slotmap.toolupdate.plist` | 51 | Unused |
| `scripts/schedulers/install_scheduler.sh` | 77 | Unused |
| `scripts/schedulers/slotmap-toolupdate.service` | 25 | Unused |
| `scripts/schedulers/slotmap-toolupdate.timer` | 18 | Unused |
| `scripts/schedulers/sync_launchd.sh` | 182 | Unused |
| `scripts/auto_update_tools.sh` | 26 | Unused |
| `scripts/sync_gh_auth.sh` | 72 | Unused |
| `scripts/update_tools_mac.sh` | 74 | Unused |
| `scripts/update_tools_remote.sh` | 96 | Unused |
| `scripts/update_tools_with_remotes.sh` | 120 | Unused |
| `scripts/generate_diagrams.sh` | 111 | Replaced by render_diagrams.sh |

### Documentation Removed (~2500 lines)

| Document | Lines | Why Removed |
|----------|-------|-------------|
| `docs/AUTO_UPDATE_SETUP.md` | 236 | Scheduler feature unused |
| `docs/DECISION_MODERN_SCHEDULERS.md` | 255 | Scheduler feature unused |
| `docs/SCHEDULER_DOCS_INDEX.md` | 214 | Scheduler feature unused |
| `docs/SCHEDULER_IMPLEMENTATION.md` | 537 | Scheduler feature unused |
| `docs/SCHEDULER_RESEARCH.md` | 363 | Scheduler feature unused |
| `docs/HOSTNAME_CONFIGURATION.md` | 484 | Replaced by env pattern |
| `docs/SSH_KEY_AUDIT.md` | 221 | Replaced by new SSH docs |
| `docs/SSH_KEY_SAFETY_AUDIT.md` | 224 | Replaced by new SSH docs |
| `docs/SSH_KEY_SYNC_PLAN.md` | 195 | Replaced by new SSH docs |
| `docs/DYNAMIC_USERNAME_RESOLUTION.md` | 212 | Superseded |

### Other Files Removed

| File | Why |
|------|-----|
| `DO_NOT_MODIFY.md` | Obsolete |
| `SUMMARY.md` | Obsolete |
| `TEST_BRANCH_README.md` | Obsolete |
| Various `.mmd` diagram files | Replaced by new diagrams |

---

## Connection Workflow Comparison

### Current Branch Workflow

```bash
# 1. Deploy (must pass flags every time)
./scripts/deploy_remote_devcontainer.sh \
  --remote-host c0802s4.ny5 \
  --remote-user rmanaloto

# 2. Connect (exposed on all interfaces)
ssh -p 9222 rmanaloto@c0802s4.ny5

# 3. For GitHub access (may need key mounted)
# Depends on REMOTE_SSH_SYNC_DIR bind mount
```

### Modernization Branch Workflow

```bash
# 1. Create local config (one-time)
cp config/env/devcontainer.env.example config/env/devcontainer.env
vim config/env/devcontainer.env
# Set: DEVCONTAINER_REMOTE_HOST, DEVCONTAINER_REMOTE_USER, DEVCONTAINER_SSH_PORT

# 2. Deploy (no flags needed!)
./scripts/deploy_remote_devcontainer.sh

# 3. Generate SSH config (one-time)
./scripts/generate_cpp_devcontainer_ssh_config.sh

# 4. Connect (via ProxyJump, localhost-only binding)
ssh -F ~/.ssh/cpp-devcontainer.conf cpp-devcontainer

# 5. GitHub access works automatically via forwarded agent
git push origin main  # Uses Mac's SSH agent through the chain
```

---

## Known Bugs in Current Branch

This section identifies **actual bugs** (not just missing features) in the `security-fixes-phase1` branch that need to be fixed based on the comparison analysis.

### 🚨 Critical (Security Vulnerabilities)

| Bug | Location | Impact | Fix Required |
|-----|----------|--------|--------------|
| **SSH port exposed on all interfaces** | `devcontainer.json:10` | Container SSH is accessible from any network interface (`0.0.0.0:9222`), not just localhost | Change `-p 9222:2222` → `-p 127.0.0.1:9222:2222` |
| **SSH directory bind-mounted** | `devcontainer.json:22` | Mounts entire `~/.ssh` directory into container; any compromise exposes private keys | Replace with SSH agent socket mount (`SSH_AUTH_SOCK`) |

### ⚠️ High Priority (Portability/Reliability)

| Bug | Location | Impact | Fix Required |
|-----|----------|--------|--------------|
| **Hardcoded hostname `c0802s4.ny5`** | `scripts/deploy_remote_devcontainer.sh:32`, `scripts/test_devcontainer_ssh.sh:22`, `scripts/sync_gh_auth.sh:7` | Scripts fail for any user with different remote host; hostname is user-specific | Remove hardcoded default, require config file or CLI arg |
| **No hardcoded refs CI guard** | Missing | Hardcoded hostnames/usernames can be accidentally committed to git | Add `hardcoded-guard.yml` workflow |
| **macOS SSH config breaks Linux** | `.devcontainer/scripts/post_create.sh` | `UseKeychain` directive in copied SSH config causes errors on Linux containers | Filter out macOS-specific directives |

### ⚡ Medium Priority (Build Reliability)

| Bug | Location | Impact | Fix Required |
|-----|----------|--------|--------------|
| **No stale CMake cache detection** | `.devcontainer/scripts/post_create.sh` | If workspace path changes, old `CMakeCache.txt` has wrong paths causing build failures | Detect and remove stale cache on path mismatch |
| **GitHub SSH only works on port 22** | `.devcontainer/scripts/post_create.sh` | Corporate firewalls may block port 22; GitHub supports port 443 alternative | Add GitHub SSH over port 443 configuration |

### Evidence from Code Review

**Bug 1: SSH port on all interfaces**
```json
// devcontainer.json:9-11
"runArgs": [
  ...
  "-p",
  "9222:2222"  // BUG: Should be "127.0.0.1:9222:2222"
]
```

**Bug 2: SSH directory bind-mount**
```json
// devcontainer.json:22
"source=${localEnv:REMOTE_SSH_SYNC_DIR},target=/home/${env:DEVCONTAINER_USER}/.ssh,type=bind,consistency=cached"
// BUG: Private keys exposed in container
```

**Bug 3: Hardcoded hostname**
```bash
# scripts/deploy_remote_devcontainer.sh:32
DEFAULT_REMOTE_HOST="${DEFAULT_REMOTE_HOST:-c0802s4.ny5}"  # BUG: User-specific

# scripts/test_devcontainer_ssh.sh:22
HOST="c0802s4.ny5"  # BUG: User-specific
```

### Bug Severity Scoring

| Bug | Security Impact | Portability Impact | Reliability Impact | Total Score |
|-----|-----------------|-------------------|-------------------|-------------|
| SSH on all interfaces | 🔴 Critical (10) | - | - | **10** |
| SSH dir bind-mount | 🔴 Critical (10) | - | - | **10** |
| Hardcoded hostname | - | 🔴 Critical (10) | - | **10** |
| No CI guard | 🟡 Medium (5) | 🟡 Medium (5) | - | **10** |
| macOS SSH config | - | - | 🟠 High (7) | **7** |
| No stale cache detection | - | - | 🟡 Medium (5) | **5** |
| GitHub SSH port 22 only | - | - | 🟡 Medium (5) | **5** |

**Recommendation**: Fix all Critical and High priority bugs before any new feature work.

---

## Adoption Plan

This section details exactly what we will adopt from `modernization.20251118` into `security-fixes-phase1`.

### High Priority (Security) - MUST DO

| Item | What It Does | Why | Files Changed |
|------|--------------|-----|---------------|
| **SSH agent socket mounting** | Replace `~/.ssh` bind-mount with `SSH_AUTH_SOCK` socket mount | Private keys never enter container | `devcontainer.json` |
| **Localhost-only port binding** | Change `-p 9222:2222` to `-p 127.0.0.1:9222:2222` | Container SSH not exposed on network | `devcontainer.json` |
| **config/env/devcontainer.env** | Gitignored local config file for host/user/port | Keeps hostnames/credentials out of git | `config/env/*`, `.gitignore` |
| **CI hardcoded refs guard** | GitHub Actions workflow that fails on personal hostnames | Prevents accidental commits | `.github/workflows/hardcoded-guard.yml` |

### Medium Priority (Reliability) - SHOULD DO

| Item | What It Does | Why | Files Changed |
|------|--------------|-----|---------------|
| **SSH config generator** | Script creates `~/.ssh/cpp-devcontainer.conf` with ProxyJump | Simplifies connection to localhost-bound container | `scripts/generate_cpp_devcontainer_ssh_config.sh` |
| **GitHub SSH over 443** | Configure `ssh.github.com:443` in post_create.sh | Works through corporate firewalls | `.devcontainer/scripts/post_create.sh` |
| **macOS SSH config filter** | Remove `UseKeychain` directive in post_create.sh | Fixes Linux compatibility errors | `.devcontainer/scripts/post_create.sh` |
| **Stale CMake cache detection** | Remove CMakeCache.txt if workspace path changed | Prevents build path mismatch issues | `.devcontainer/scripts/post_create.sh` |
| **Remove hardcoded hostname** | Remove `c0802s4.ny5` default from deploy script | Makes scripts portable for any user | `scripts/deploy_remote_devcontainer.sh` |
| **Load config env file** | Scripts source `config/env/devcontainer.env` if present | No need to pass flags every time | `scripts/deploy_remote_devcontainer.sh`, `scripts/run_local_devcontainer.sh`, `scripts/test_devcontainer_ssh.sh` |

### Low Priority (Cleanup) - NICE TO HAVE

| Item | Lines Removed/Added | Why | Files Changed |
|------|---------------------|-----|---------------|
| Remove scheduler scripts | -500 lines | Unused feature | `scripts/schedulers/*` |
| Remove update_tools_*.sh | -400 lines | Unused | `scripts/update_tools_*.sh`, `scripts/sync_gh_auth.sh` |
| Remove obsolete docs | -2500 lines | Outdated SSH/scheduler docs | `docs/SCHEDULER_*.md`, `docs/SSH_KEY_*.md`, etc. |
| Add status_devcontainer.sh | +21 lines | Useful diagnostics | `scripts/status_devcontainer.sh` |
| Add SSH documentation | +100 lines | Better guidance | `docs/ssh-configurations.md`, `docs/ssh-key-management-options.md` |

### DO NOT ADOPT (Keep Ours)

| Item | Why Keep Ours |
|------|---------------|
| `CMakeLists.txt` | Our version has benchmarks, BOLT, LTO, clang-tidy, IWYU options |
| `CMakePresets.json` | Our version has full sanitizer presets (ASan, UBSan, TSan, MSan, CFI, Scudo, RTSan) |
| `benchmarks/` directory | Just added Google Benchmark + chrono perf tests |
| `.clang-tidy` | Need for static analysis |
| `.iwyu.imp` | Need for include-what-you-use mappings |

---

## Implementation Steps

When ready to adopt, execute these steps in order:

### Step 1: Create config/env/ Directory Structure

```bash
mkdir -p config/env
```

**Create `config/env/README.md`:**
```markdown
# Local Environment Overrides

Use this directory to store machine-specific settings for devcontainer scripts.
The file `devcontainer.env` is NOT tracked (see .gitignore).

## Setup
cp config/env/devcontainer.env.example config/env/devcontainer.env
# Edit with your values
```

**Create `config/env/devcontainer.env.example`:**
```bash
# Devcontainer script defaults (copy to devcontainer.env and edit)
DEVCONTAINER_REMOTE_HOST=myhost.example.com
DEVCONTAINER_REMOTE_USER=myuser
DEVCONTAINER_SSH_PORT=9222
```

### Step 2: Update .gitignore

```bash
echo "" >> .gitignore
echo "# Local environment overrides (not committed)" >> .gitignore
echo "config/env/devcontainer.env" >> .gitignore
```

### Step 3: Update devcontainer.json

Change SSH port binding to localhost-only:
```diff
  "runArgs": [
    "--cap-add=SYS_PTRACE",
    "--security-opt=seccomp=unconfined",
    "-p",
-   "9222:2222"
+   "127.0.0.1:${localEnv:DEVCONTAINER_SSH_PORT:-9222}:2222"
  ],
```

Add SSH_AUTH_SOCK environment variable:
```diff
  "containerEnv": {
    "CC": "clang-21",
    "CXX": "clang++-21",
    ...
+   "SSH_AUTH_SOCK": "/tmp/ssh-agent.socket"
  },
```

Replace SSH key mount with agent socket mount:
```diff
  "mounts": [
    "source=slotmap-vcpkg,target=/opt/vcpkg/downloads,type=volume",
-   "source=${localEnv:REMOTE_SSH_SYNC_DIR},target=/home/${env:DEVCONTAINER_USER}/.ssh,type=bind,consistency=cached"
+   "source=${localEnv:SSH_AUTH_SOCK},target=/tmp/ssh-agent.socket,type=bind,consistency=cached"
  ],
```

Update sshd feature port:
```diff
  "features": {
    "ghcr.io/devcontainers/features/sshd:1": {
      "version": "latest",
-     "port": "9222",
+     "port": "${localEnv:DEVCONTAINER_SSH_PORT:-9222}",
      ...
    }
  }
```

### Step 4: Add New Scripts

Copy from modernization branch:
```bash
git show origin/modernization.20251118:scripts/generate_cpp_devcontainer_ssh_config.sh > scripts/generate_cpp_devcontainer_ssh_config.sh
git show origin/modernization.20251118:scripts/check_hardcoded_refs.sh > scripts/check_hardcoded_refs.sh
git show origin/modernization.20251118:scripts/status_devcontainer.sh > scripts/status_devcontainer.sh
chmod +x scripts/generate_cpp_devcontainer_ssh_config.sh scripts/check_hardcoded_refs.sh scripts/status_devcontainer.sh
```

### Step 5: Add CI Workflow

```bash
mkdir -p .github/workflows
git show origin/modernization.20251118:.github/workflows/hardcoded-guard.yml > .github/workflows/hardcoded-guard.yml
```

### Step 6: Update deploy_remote_devcontainer.sh

Add config file loading at the top (after `cd "$REPO_ROOT"`):
```bash
# Optional local env overrides
CONFIG_ENV_FILE=${CONFIG_ENV_FILE:-"$REPO_ROOT/config/env/devcontainer.env"}
if [[ -f "$CONFIG_ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_ENV_FILE"
fi
```

Remove hardcoded default and add validation:
```diff
- DEFAULT_REMOTE_HOST="${DEFAULT_REMOTE_HOST:-c0802s4.ny5}"
+ DEFAULT_REMOTE_HOST="${DEFAULT_REMOTE_HOST:-""}"

# After parsing args, add:
+ REMOTE_HOST=${REMOTE_HOST:-${DEVCONTAINER_REMOTE_HOST:-${DEFAULT_REMOTE_HOST:-""}}}
+ [[ -n "$REMOTE_HOST" ]] || die "Remote host required (set DEVCONTAINER_REMOTE_HOST or pass --remote-host)"
```

### Step 7: Update post_create.sh

Add macOS SSH config filtering:
```bash
# Sanitize macOS SSH config (UseKeychain is unsupported on Linux)
SSH_CONFIG_FILE="$SSH_TARGET/config"
if [[ -f "$SSH_CONFIG_FILE" ]] && grep -q "UseKeychain" "$SSH_CONFIG_FILE"; then
  cp "$SSH_CONFIG_FILE" "$SSH_TARGET/config.macbak"
  grep -v "UseKeychain" "$SSH_TARGET/config.macbak" > "$SSH_CONFIG_FILE"
  chmod 600 "$SSH_CONFIG_FILE"
  echo "[post_create] Filtered UseKeychain from ~/.ssh/config"
fi
```

Add GitHub SSH over 443:
```bash
# Force GitHub SSH over 443 (port 22 often blocked)
{
  echo ""
  echo "# GitHub SSH over 443 (added by post_create.sh)"
  echo "Host github.com"
  echo "  Hostname ssh.github.com"
  echo "  Port 443"
  echo "  User git"
} >> "$SSH_CONFIG_FILE"
```

Add stale CMake cache detection:
```bash
BUILD_DIR="${WORKSPACE_DIR}/build/clang-debug"
CACHE_FILE="${BUILD_DIR}/CMakeCache.txt"
if [[ -f "$CACHE_FILE" ]]; then
  if ! grep -q "CMAKE_HOME_DIRECTORY:INTERNAL=${WORKSPACE_DIR}" "$CACHE_FILE"; then
    echo "[post_create] Removing stale CMake cache (workspace path changed)"
    rm -rf "$BUILD_DIR"
  fi
fi
```

### Step 8: Add New Documentation

```bash
git show origin/modernization.20251118:docs/ssh-configurations.md > docs/ssh-configurations.md
git show origin/modernization.20251118:docs/ssh-key-management-options.md > docs/ssh-key-management-options.md
```

### Step 9: Test the Changes

```bash
# 1. Create your local config
cp config/env/devcontainer.env.example config/env/devcontainer.env
# Edit with your actual host/user/port

# 2. Deploy (no flags needed now!)
./scripts/deploy_remote_devcontainer.sh

# 3. Generate SSH config
./scripts/generate_cpp_devcontainer_ssh_config.sh

# 4. Connect via ProxyJump
ssh -F ~/.ssh/cpp-devcontainer.conf cpp-devcontainer

# 5. Verify GitHub SSH works inside container
ssh -T git@github.com
```

---

## Migration Path

### Option 1: Cherry-Pick (Recommended)

Adopt improvements incrementally while keeping our unique additions:

```bash
# 1. Create config env pattern
mkdir -p config/env
git show origin/modernization.20251118:config/env/README.md > config/env/README.md
git show origin/modernization.20251118:config/env/devcontainer.env.example > config/env/devcontainer.env.example

# 2. Update .gitignore
echo "config/env/devcontainer.env" >> .gitignore

# 3. Update devcontainer.json for SSH socket + localhost binding
# (manual edit to preserve our structure)

# 4. Add new scripts
git show origin/modernization.20251118:scripts/generate_cpp_devcontainer_ssh_config.sh > scripts/generate_cpp_devcontainer_ssh_config.sh
git show origin/modernization.20251118:scripts/check_hardcoded_refs.sh > scripts/check_hardcoded_refs.sh
git show origin/modernization.20251118:scripts/status_devcontainer.sh > scripts/status_devcontainer.sh

# 5. Add CI workflow
git show origin/modernization.20251118:.github/workflows/hardcoded-guard.yml > .github/workflows/hardcoded-guard.yml

# 6. Add new docs
git show origin/modernization.20251118:docs/ssh-configurations.md > docs/ssh-configurations.md
git show origin/modernization.20251118:docs/ssh-key-management-options.md > docs/ssh-key-management-options.md
```

### Option 2: Merge with Conflicts

```bash
git merge origin/modernization.20251118
# Resolve conflicts keeping:
# - Our CMakeLists.txt, CMakePresets.json, benchmarks/
# - Our .clang-tidy, .iwyu.imp
# - Their devcontainer.json SSH changes, scripts, docs
```

### Option 3: Manual Adoption

Copy specific patterns/code from modernization branch as needed, testing each change.

---

## Appendix: Key File Differences

### devcontainer.json

```diff
  "runArgs": [
    "--cap-add=SYS_PTRACE",
    "--security-opt=seccomp=unconfined",
    "-p",
-   "9222:2222"
+   "127.0.0.1:${localEnv:DEVCONTAINER_SSH_PORT:-9222}:2222"
  ],
  "containerEnv": {
    ...
+   "SSH_AUTH_SOCK": "/tmp/ssh-agent.socket"
  },
  "mounts": [
    "source=slotmap-vcpkg,target=/opt/vcpkg/downloads,type=volume",
-   "source=${localEnv:REMOTE_SSH_SYNC_DIR},target=/home/${env:DEVCONTAINER_USER}/.ssh,type=bind,consistency=cached"
+   "source=${localEnv:SSH_AUTH_SOCK},target=/tmp/ssh-agent.socket,type=bind,consistency=cached"
  ],
```

### deploy_remote_devcontainer.sh

```diff
+ # Optional local env overrides
+ CONFIG_ENV_FILE=${CONFIG_ENV_FILE:-"$REPO_ROOT/config/env/devcontainer.env"}
+ if [[ -f "$CONFIG_ENV_FILE" ]]; then
+   source "$CONFIG_ENV_FILE"
+ fi

- DEFAULT_REMOTE_HOST="${DEFAULT_REMOTE_HOST:-c0802s4.ny5}"
+ DEFAULT_REMOTE_HOST="${DEFAULT_REMOTE_HOST:-""}"
+ REMOTE_HOST="${DEVCONTAINER_REMOTE_HOST:-${DEFAULT_REMOTE_HOST:-""}}"

+ [[ -n "$REMOTE_HOST" ]] || die "Remote host is required (set DEVCONTAINER_REMOTE_HOST or pass --remote-host)"
```
