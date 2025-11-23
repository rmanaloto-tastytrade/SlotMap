# Project Plan

## Phase 0: Infrastructure Configuration (CURRENT PRIORITY)

### Task 0.1: Configure Remote Host for c0802s4.ny5 ✅ URGENT
**Status:** 🔄 In Progress
**Priority:** Critical
**Owner:** DevOps
**Timeline:** Immediate (before any other work)

**Objective:** Update all scripts and configuration to use c0802s4.ny5 instead of c24s1.ch2 to avoid interrupting ongoing work.

**Files Requiring Updates:**

**Critical (Scripts - Default Values):**
1. `scripts/deploy_remote_devcontainer.sh:33`
   - Current: `DEFAULT_REMOTE_HOST="${DEFAULT_REMOTE_HOST:-c24s1.ch2}"`
   - Update to: `DEFAULT_REMOTE_HOST="${DEFAULT_REMOTE_HOST:-c0802s4.ny5}"`

2. `scripts/test_devcontainer_ssh.sh:22`
   - Current: `HOST="c24s1.ch2"`
   - Update to: `HOST="c0802s4.ny5"`

3. `scripts/test_devcontainer_ssh.sh:126` (help text)
   - Update example from c24s1.ch2 to c0802s4.ny5

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
grep -r "c24s1\.ch2" docs/ README.md CLAUDE.md TEST_BRANCH_README.md
```

**Success Criteria:**
- ✅ All script defaults point to c0802s4.ny5
- ✅ Documentation consistently uses c0802s4.ny5 as example
- ✅ Scripts maintain backward compatibility via flags
- ✅ No hardcoded references to c24s1.ch2 remain

**Dependencies:** None (blocks all other work)
**Risk Level:** Low (non-breaking change, flag-based override maintained)

---

### Task 0.2: Security Fixes - Phase 1 🔐
**Status:** ✅ Completed (security-fixes-phase1 branch)
**Priority:** Critical
**Timeline:** Ready for testing

**Implemented Changes:**
1. ✅ Milestone 1.1: Stop syncing private keys (rsync filters)
2. ✅ Milestone 1.2: SSH agent forwarding support
3. 📋 Milestone 1.3: Remove SSH keys bind mount (pending)

**Reference:** See `docs/REFACTORING_ROADMAP.md` for details

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

**Current Priority:** Phase 0, Task 0.1 - Configure c0802s4.ny5 hostname
**Next Up:** Phase 0, Task 0.2 - Complete security fixes testing
**Blocking:** All Phase 1+ work until Phase 0 complete

**Key Files:**
- This plan: `PROJECT_PLAN.md`
- Security roadmap: `docs/REFACTORING_ROADMAP.md`
- Implementation guide: `docs/AI_AGENT_CONTEXT.md`
- Testing procedures: `TEST_BRANCH_README.md`
