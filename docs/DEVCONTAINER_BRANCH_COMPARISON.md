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

## Recommendations Summary

### High Priority (Security) - MUST ADOPT

| Item | Reason |
|------|--------|
| SSH agent socket mounting | Private keys never in container |
| Localhost-only port binding | Container SSH not exposed on network |
| config/env/devcontainer.env pattern | Secrets stay out of git |
| CI hardcoded refs guard | Prevent accidental commits |

### Medium Priority (Reliability) - SHOULD ADOPT

| Item | Reason |
|------|--------|
| SSH config generator script | Simplifies ProxyJump workflow |
| GitHub SSH over 443 | Firewall-friendly |
| macOS SSH config filtering | Fixes UseKeychain errors on Linux |
| Stale CMake cache detection | Prevents build path issues |
| Pinned devcontainer CLI version | Reproducible builds |

### Low Priority (Cleanup) - NICE TO HAVE

| Item | Reason |
|------|--------|
| Remove scheduler scripts (~500 lines) | Dead code |
| Remove update scripts (~400 lines) | Dead code |
| Remove obsolete docs (~2500 lines) | Outdated |
| Add status_devcontainer.sh | Useful diagnostics |
| Add new SSH documentation | Better guidance |

### DO NOT ADOPT (Keep Ours)

| Item | Reason |
|------|--------|
| CMakeLists.txt | Our version has benchmarks, sanitizers |
| CMakePresets.json | Our version has full sanitizer presets |
| benchmarks/ directory | We just added this |
| .clang-tidy | We need this |
| .iwyu.imp | We need this |

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
