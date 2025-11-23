# Hostname Configuration: c24s1.ch2 → c0802s4.ny5

**Status:** 📋 Pending Implementation
**Priority:** Critical (Phase 0, Task 0.1)
**Created:** 2025-01-23
**Objective:** Update all scripts and documentation to use c0802s4.ny5 as the default remote host

---

## Executive Summary

All scripts and documentation currently reference `c24s1.ch2` as the default remote host. To avoid interrupting ongoing work on c24s1.ch2, we need to update all references to use `c0802s4.ny5` instead.

**Good News:** Both critical scripts already support the `--remote-host` flag, so this is primarily a default value update, not a breaking change.

---

## Files Requiring Updates

### Critical Files (Scripts - Must Update)

These files contain hardcoded default values that must be changed:

#### 1. scripts/deploy_remote_devcontainer.sh:33

**Current:**
```bash
DEFAULT_REMOTE_HOST="${DEFAULT_REMOTE_HOST:-c24s1.ch2}"
```

**Update to:**
```bash
DEFAULT_REMOTE_HOST="${DEFAULT_REMOTE_HOST:-c0802s4.ny5}"
```

**Impact:** Changes default remote host for deployment
**Risk:** Low (flag override still works)

---

#### 2. scripts/test_devcontainer_ssh.sh:22

**Current:**
```bash
HOST="c24s1.ch2"
```

**Update to:**
```bash
HOST="c0802s4.ny5"
```

**Impact:** Changes default host for SSH testing
**Risk:** Low (flag override still works)

---

#### 3. scripts/test_devcontainer_ssh.sh:126 (Help Text)

**Current:**
```bash
echo "[ssh-remote]   2. Connect with: ssh -A -p 9222 rmanaloto@c24s1.ch2"
```

**Update to:**
```bash
echo "[ssh-remote]   2. Connect with: ssh -A -p 9222 rmanaloto@c0802s4.ny5"
```

**Impact:** Help text example
**Risk:** None (documentation only)

---

### Documentation Files (Should Update for Consistency)

These files contain c24s1.ch2 as examples and should be updated for consistency:

#### 4. README.md
- Line references: Various examples
- Update: Replace all c24s1.ch2 → c0802s4.ny5

#### 5. CLAUDE.md
- Line references: SSH connection examples
- Update: Replace all c24s1.ch2 → c0802s4.ny5

#### 6. TEST_BRANCH_README.md
- Line references: Testing procedures (multiple)
- Update: Replace all c24s1.ch2 → c0802s4.ny5

#### 7. docs/CURRENT_WORKFLOW.md
- Line references: ~40+ occurrences in architecture diagrams and examples
- Update: Replace all c24s1.ch2 → c0802s4.ny5
- Note: ASCII diagrams and workflow descriptions

#### 8. docs/WORKFLOW_DIAGRAMS.md
- Line references: ~25+ occurrences in Mermaid diagrams
- Update: Replace all c24s1.ch2 → c0802s4.ny5
- Note: All Mermaid diagram references

#### 9. docs/CRITICAL_FINDINGS.md
- Line references: ~15 occurrences in examples and commands
- Update: Replace all c24s1.ch2 → c0802s4.ny5

#### 10. docs/AI_AGENT_CONTEXT.md
- Line references: ~20 occurrences in validation commands
- Update: Replace all c24s1.ch2 → c0802s4.ny5
- Critical: Machine-readable commands used by AI agents

#### 11. docs/REFACTORING_ROADMAP.md
- Line references: ~25 occurrences in procedures
- Update: Replace all c24s1.ch2 → c0802s4.ny5

#### 12. docs/remote-docker-context.md
- Line references: Docker context examples
- Update: Replace all c24s1.ch2 → c0802s4.ny5

#### 13. docs/remote-devcontainer.md
- Line references: Deployment workflow examples
- Update: Replace all c24s1.ch2 → c0802s4.ny5

#### 14. docs/devcontainer-ssh-docker-context.md
- Line references: SSH and Docker context examples
- Update: Replace all c24s1.ch2 → c0802s4.ny5

#### 15. docs/ai_agent_action_plan.md
- Line references: Remote host specifications
- Update: Replace all c24s1.ch2 → c0802s4.ny5

---

## Implementation Strategy

### Step 1: Update Critical Scripts (5 minutes)

```bash
cd /Users/ray.manaloto@tastytrade.com/dev/github/SergeyMakeev/SlotMap-security-test

# Update deploy script
sed -i '' 's/DEFAULT_REMOTE_HOST:-c24s1\.ch2/DEFAULT_REMOTE_HOST:-c0802s4.ny5/g' \
  scripts/deploy_remote_devcontainer.sh

# Update test script default
sed -i '' 's/HOST="c24s1\.ch2"/HOST="c0802s4.ny5"/g' \
  scripts/test_devcontainer_ssh.sh

# Update test script help text
sed -i '' 's/rmanaloto@c24s1\.ch2/rmanaloto@c0802s4.ny5/g' \
  scripts/test_devcontainer_ssh.sh
```

### Step 2: Update All Documentation (10 minutes)

```bash
# Update all documentation files in one pass
find . -type f \( -name "*.md" -o -name "*.sh" \) \
  -not -path "./.git/*" \
  -exec sed -i '' 's/c24s1\.ch2/c0802s4.ny5/g' {} +
```

**Note:** This will update ALL occurrences. Review the changes before committing.

### Step 3: Verify Changes

```bash
# Verify script defaults
grep "DEFAULT_REMOTE_HOST" scripts/deploy_remote_devcontainer.sh
grep "^HOST=" scripts/test_devcontainer_ssh.sh

# Verify no c24s1.ch2 references remain
grep -r "c24s1\.ch2" --include="*.sh" --include="*.md" . | grep -v ".git/"

# Expected: No results (except this file)
```

### Step 4: Test Scripts

```bash
# Test that scripts still accept flags
./scripts/deploy_remote_devcontainer.sh --help
./scripts/test_devcontainer_ssh.sh --help

# Test with old host (should still work with flag)
./scripts/test_devcontainer_ssh.sh --host c24s1.ch2 --help

# Test with new default
./scripts/deploy_remote_devcontainer.sh --help | grep c0802s4.ny5
```

---

## Validation Checklist

Before marking this task complete, verify:

- [ ] `scripts/deploy_remote_devcontainer.sh:33` uses c0802s4.ny5 as default
- [ ] `scripts/test_devcontainer_ssh.sh:22` uses c0802s4.ny5 as default
- [ ] All help text references c0802s4.ny5
- [ ] README.md uses c0802s4.ny5 in examples
- [ ] CLAUDE.md uses c0802s4.ny5 in examples
- [ ] TEST_BRANCH_README.md uses c0802s4.ny5 in examples
- [ ] All docs/*.md files use c0802s4.ny5 consistently
- [ ] No remaining c24s1.ch2 references (except historical/archived docs)
- [ ] Scripts still accept `--remote-host` flag for override
- [ ] Environment variable `DEFAULT_REMOTE_HOST` still works

---

## Backward Compatibility

**Maintained:** Scripts still support explicit host specification via:

1. **Command-line flag:**
   ```bash
   ./scripts/deploy_remote_devcontainer.sh --remote-host c24s1.ch2
   ```

2. **Environment variable:**
   ```bash
   DEFAULT_REMOTE_HOST=c24s1.ch2 ./scripts/deploy_remote_devcontainer.sh
   ```

3. **Per-invocation override:**
   ```bash
   ./scripts/test_devcontainer_ssh.sh --host c24s1.ch2
   ```

---

## Risk Assessment

**Risk Level:** Low

**Rationale:**
- Non-breaking change (flag-based override maintained)
- Only default values changing
- Scripts already support host configuration
- Documentation updates have no functional impact

**Potential Issues:**
- Users with muscle memory of c24s1.ch2 may be confused (mitigated by documentation)
- CI/CD pipelines hardcoded to c24s1.ch2 (none identified)
- Cached SSH keys for c24s1.ch2:9222 (expected, users will need to update known_hosts)

**Mitigation:**
- Clear documentation of change
- Maintain backward compatibility flags
- Update all examples consistently

---

## Success Criteria

1. ✅ All script defaults point to c0802s4.ny5
2. ✅ All documentation consistently uses c0802s4.ny5 as example
3. ✅ Scripts maintain backward compatibility via flags
4. ✅ No hardcoded c24s1.ch2 references remain (except archived docs)
5. ✅ Validation tests pass on c0802s4.ny5

---

## Timeline

- **Estimated Duration:** 15-20 minutes
- **Blocking:** No dependencies
- **Priority:** Complete before any Phase 1 work

---

## References

- **Project Plan:** See `PROJECT_PLAN.md` Phase 0, Task 0.1
- **Security Fixes:** See `docs/REFACTORING_ROADMAP.md`
- **Workflow Documentation:** See `docs/CURRENT_WORKFLOW.md`
- **Validation Commands:** See `docs/AI_AGENT_CONTEXT.md`

---

## Automated Update Script

For convenience, here's a complete automation script:

```bash
#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

echo "Updating hostname: c24s1.ch2 → c0802s4.ny5"

# Update all files (scripts and docs)
find . -type f \( -name "*.md" -o -name "*.sh" \) \
  -not -path "./.git/*" \
  -not -path "./docs/HOSTNAME_CONFIGURATION.md" \
  -exec sed -i '' 's/c24s1\.ch2/c0802s4.ny5/g' {} +

# Verify changes
echo "Verification:"
grep "DEFAULT_REMOTE_HOST" scripts/deploy_remote_devcontainer.sh || echo "✅ Script updated"
grep "^HOST=" scripts/test_devcontainer_ssh.sh || echo "✅ Test script updated"

# Check for remaining references (should only be this file)
REMAINING=$(grep -r "c24s1\.ch2" --include="*.sh" --include="*.md" . 2>/dev/null | grep -v ".git/" | grep -v "HOSTNAME_CONFIGURATION.md" | wc -l)
if [ "$REMAINING" -eq 0 ]; then
  echo "✅ All references updated"
else
  echo "⚠️  $REMAINING references still found"
  grep -r "c24s1\.ch2" --include="*.sh" --include="*.md" . 2>/dev/null | grep -v ".git/" | grep -v "HOSTNAME_CONFIGURATION.md"
fi

echo "Done. Review changes with: git diff"
```

Save as `scripts/update_hostname.sh` and run with `bash scripts/update_hostname.sh`
