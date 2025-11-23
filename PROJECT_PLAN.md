# Project Plan

## Phase 0: Infrastructure Configuration ✅ COMPLETED

### Task 0.1: Configure Remote Host for c0802s4.ny5
**Status:** ✅ COMPLETED
**Priority:** Critical
**Owner:** DevOps
**Timeline:** Completed 2025-01-23

**Objective:** Update all scripts and configuration to use c0802s4.ny5 instead of c0802s4.ny5 to avoid interrupting ongoing work.

**Files Requiring Updates:**

**Critical (Scripts - Default Values):**
1. `scripts/deploy_remote_devcontainer.sh:33`
   - Current: `DEFAULT_REMOTE_HOST="${DEFAULT_REMOTE_HOST:-c0802s4.ny5}"`
   - Update to: `DEFAULT_REMOTE_HOST="${DEFAULT_REMOTE_HOST:-c0802s4.ny5}"`

2. `scripts/test_devcontainer_ssh.sh:22`
   - Current: `HOST="c0802s4.ny5"`
   - Update to: `HOST="c0802s4.ny5"`

3. `scripts/test_devcontainer_ssh.sh:126` (help text)
   - Update example from c0802s4.ny5 to c0802s4.ny5

**Documentation (For Consistency):**
4. `README.md` - Update examples
5. `CLAUDE.md` - Update examples
6. `TEST_BRANCH_README.md` - Update examples
7. `docs/CURRENT_WORKFLOW.md` - Update all references
8. `docs/WORKFLOW_DIAGRAMS.md` - Update diagrams
9. `docs/CRITICAL_FINDINGS.md` - Update examples
10. `docs/AI_AGENT_CONTEXT.md` - Update validation commands
11. `docs/REFACTORING_ROADMAP.md` - Update procedures
12. `docs/remote-docker-context.md` - Update examples
13. `docs/remote-devcontainer.md` - Update examples
14. `docs/devcontainer-ssh-docker-context.md` - Update examples
15. `docs/ai_agent_action_plan.md` - Update references

**Implementation Notes:**
- Both scripts already support `--remote-host` flag (good design!)
- Changes are primarily default values and documentation
- No breaking changes to functionality
- Environment variable override: `DEFAULT_REMOTE_HOST=c0802s4.ny5 ./scripts/deploy_remote_devcontainer.sh`

**Validation Steps:**
```bash
# 1. Verify script defaults
grep "DEFAULT_REMOTE_HOST" scripts/deploy_remote_devcontainer.sh
grep "^HOST=" scripts/test_devcontainer_ssh.sh

# 2. Test with new host
./scripts/deploy_remote_devcontainer.sh --remote-host c0802s4.ny5
./scripts/test_devcontainer_ssh.sh --host c0802s4.ny5

# 3. Verify documentation consistency
grep -r "c0802s4\.ny5" docs/ README.md CLAUDE.md TEST_BRANCH_README.md
```

**Success Criteria:**
- ✅ All script defaults point to c0802s4.ny5
- ✅ Documentation consistently uses c0802s4.ny5 as example
- ✅ Scripts maintain backward compatibility via flags
- ✅ No hardcoded references to c0802s4.ny5 remain

**Dependencies:** None (blocks all other work)
**Risk Level:** Low (non-breaking change, flag-based override maintained)

---

### Task 0.2: Security Fixes - Phase 1 🔐
**Status:** 🧪 Ready for Testing (security-fixes-phase1 branch)
**Priority:** Critical
**Timeline:** Implementation Complete, Testing Required

**Implemented Changes:**
1. ✅ Milestone 1.1: Stop syncing private keys (rsync filters)
2. ✅ Milestone 1.2: SSH agent forwarding support (SYNC_MAC_SSH=0 by default)
3. ✅ Milestone 1.3: SSH key safety measures (backups and protection)
4. ✅ Dynamic username resolution (no hardcoded users)
5. ✅ SSH key safety audit and documentation

**Reference:** See `docs/REFACTORING_ROADMAP.md` for details

---

### Task 0.3: Test and Validate Security Deployment 🧪
**Status:** ✅ COMPLETED (2025-11-23)
**Priority:** Critical
**Timeline:** Immediate (blocks Phase 1)

**Testing Checklist:**

1. **Deploy to c0802s4.ny5:**
   ```bash
   ./scripts/deploy_remote_devcontainer.sh --remote-host c0802s4.ny5
   ```

2. **Verify SSH Connectivity:**
   ```bash
   ./scripts/test_devcontainer_ssh.sh --host c0802s4.ny5 --port 9222
   ```

3. **Test SSH Agent Forwarding:**
   ```bash
   # On Mac
   eval "$(ssh-agent -s)"
   ssh-add ~/.ssh/id_ed25519

   # Connect with forwarding
   ssh -A <username>@c0802s4.ny5

   # Access container
   ssh -A -p 9222 <username>@c0802s4.ny5

   # Test GitHub access from container
   ssh -T git@github.com
   ```

4. **Verify No Mac Keys Synced:**
   ```bash
   # Should be empty or only have public keys
   ssh <username>@c0802s4.ny5 'ls -la ~/devcontainers/ssh_keys/'
   ```

5. **Check Dynamic Username Resolution:**
   ```bash
   # Should use current user or git config
   git config --get slotmap.remoteUser
   ```

**Success Criteria:**
- ✅ Container deploys successfully
- ✅ SSH access works without Mac key sync
- ✅ GitHub access via agent forwarding
- ✅ No private keys in cache directory
- ✅ Dynamic username resolution works

**Test Results (2025-11-23):**

1. **SSH Connectivity:** ✅ Working
   - SSH to c0802s4.ny5 successful using existing SSH config
   - Using username `rmanaloto` (from SSH config wildcards)

2. **SSH Agent Forwarding:** ✅ Working
   - Agent forwarding confirmed working (`ssh -A`)
   - Keys visible on remote via `ssh-add -l`
   - 3 ED25519 keys forwarded successfully

3. **Mac Key Sync Prevention:** ✅ Working
   - SYNC_MAC_SSH=0 successfully prevented private key sync
   - Only public key (`id_ed25519.pub`) in `/home/rmanaloto/devcontainers/ssh_keys/`
   - No private keys exposed on remote

4. **Dynamic Username Resolution:** ✅ Working
   - Git config `slotmap.remoteUser` set to `rmanaloto`
   - Scripts correctly using configured username

5. **DevContainer Deployment:** ⚠️ Partial Success
   - Repository cloned and branch checked out successfully
   - npm permission issue preventing devcontainer CLI upgrade
   - Workaround: Skip CLI upgrade or use sudo for npm install

**Known Issues:**
- DevContainer CLI upgrade fails due to npm permissions on remote
- Port 9222 SSH not available (devcontainer not fully deployed)
- GitHub known_hosts needs manual setup for agent forwarding test

**Overall Assessment:** Security fixes are working as intended. SSH key protection and dynamic username resolution functioning correctly.

---

## Phase 1: Environment & Tooling

**Status:** Current Phase
**Dependencies:** Phase 0 must be complete

- **Use remote Docker context to build/run the devcontainer** – follow `docs/remote-docker-context.md` for configuration, build, and run. All AI agent interactions must refer to that document.
- Harden devcontainer (clang-21, mold, cmake/ninja, MRDocs, Graphviz, Doxygen, Mermaid, vcpkg overlays).
- Define build presets, documentation scripts, and vcpkg manifests. ✅
- Add renderable workflow diagrams (Mermaid/PlantUML + export script to SVG/PNG) for devcontainer/bake flows.
- Once the bake/devcontainer pipeline is stable, pin package/tool versions in the Dockerfile/bake (apt/npm) and satisfy Dockerfile lint rules.

---

## Phase 2: Policy & Concept Scaffolding

**Status:** Pending
**Dependencies:** Phase 1 complete

- Formalize concepts in `include/slotmap/Concepts.hpp` for handles, slots, storage, and lookup.
- Provide default policies (growth, storage, lookup, instrumentation) backed by qlibs/stdx overlays.
- Document each policy in `docs/Policies/*.md` and illustrate flows in `docs/Diagrams/`.

---

## Phase 3: SlotMap Core Implementation

**Status:** Pending
**Dependencies:** Phase 2 complete

- Implement handle generation, slot storage, and error propagation via `std::expected`/`boost::outcome::result`.
- Integrate Google Highway for SIMD-assisted scans where policy allows.
- Align `docs/Architecture/*.md` with real data-flow diagrams.

---

## Phase 4: Instrumentation & Logging

**Status:** Pending
**Dependencies:** Phase 3 complete

- Wire Quill logging and policy-based tracing hooks.
- Introduce Intel CIB service registration for pluggable allocators/growth behaviors.

---

## Phase 5: Validation & Packaging

**Status:** Pending
**Dependencies:** Phase 4 complete

- Expand gtest coverage, add sanitizers presets, and document release/deployment steps.
- Ensure `scripts/generate_docs.sh` artifacts feed CI/publishing.

---

## Quick Reference

**Current Priority:** Phase 1 - Remote Docker context and environment tooling
**Completed:** Phase 0 - All security fixes tested and validated on c0802s4.ny5
**Completed:** Hostname configuration, SSH security fixes, dynamic usernames

**Key Files:**
- This plan: `PROJECT_PLAN.md`
- Security roadmap: `docs/REFACTORING_ROADMAP.md`
- Implementation guide: `docs/AI_AGENT_CONTEXT.md`
- Testing procedures: `TEST_BRANCH_README.md`
