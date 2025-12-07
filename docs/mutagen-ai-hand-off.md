# Mutagen SSH Agent Issue – AI Hand-off

## Situation
- Goal: Mutagen two-way sync between macOS host and remote devcontainers (c090s4.ny5/c24s1.ch2) over SSH, validated as part of `verify_devcontainer.sh` (`REQUIRE_MUTAGEN=1`).
- Blocker (fixed via explicit ssh command): `mutagen sync create` launched the agent with host literal `ssh`, producing `ssh: Could not resolve hostname ssh`. The fix is to force `sync.ssh.command` and `sync.ssh.path` in `~/.mutagen.yml` (written by `scripts/setup_mutagen_host.sh`) to the wrapper that loads `~/.mutagen/cpp-devcontainer_ssh_config`.

## What’s implemented
- Host setup: `scripts/setup_mutagen_host.sh`
  - Writes `~/.mutagen/cpp-devcontainer_ssh_config` (ProxyJump, key, port) and `~/.mutagen.yml` with `sync.ssh.command`/`sync.ssh.path`; restarts daemon with the wrapper.
- Validation: `scripts/verify_mutagen.sh`
  - Uses scp-style endpoint (`user@127.0.0.1:/path`), logging ssh wrapper (`/tmp/mutagen_ssh_invocations.log`), probes a temp dir, flushes, verifies both directions.
- Devcontainer verify hook: `scripts/verify_devcontainer.sh` runs Mutagen check when `REQUIRE_MUTAGEN=1`.
- Docs: `docs/mutagen-validation.md`, `docs/mutagen-research.md`, `PROJECT_PLAN.md` updated with status, attempts, and next steps.

## Repros
1) Host SSH works:
   - `ssh -F ~/.mutagen/cpp-devcontainer_ssh_config cpp-devcontainer-mutagen 'echo ok'` ✅
2) Mutagen fails (pre-fix):
   - `CONFIG_ENV_FILE=config/env/devcontainer.c090s4.gcc14-clang21.env REQUIRE_MUTAGEN=1 scripts/verify_devcontainer.sh --require-ssh`
   - Error: `ssh: Could not resolve hostname ssh: nodename nor servname provided`
   - Log file: `/tmp/mutagen_ssh_invocations.log` shows agent host = `ssh`.
3) Minimal local (pre-fix):
   - `mutagen sync create /tmp/foo ssh://localhost/tmp` → same host=`ssh` failure.

## Hypotheses
- Mutagen CLI/daemon constructs agent command incorrectly (possibly a bug/regression in 0.18.1) when `sync.ssh.command` is unset.
- Environment/config isn’t being honored for the agent launch (ignoring `MUTAGEN_SSH_COMMAND`/config when launching agent) unless forced in `~/.mutagen.yml`.

## Next debug steps (suggested)
1) Run `MUTAGEN_LOG_LEVEL=debug mutagen daemon run` in foreground with logging ssh wrapper to capture full argv and environment during agent launch (done to confirm host is preserved post-fix).
2) If regressions reappear, try prior Mutagen release (e.g., 0.17.x) to see if bug is 0.18.x-specific and/or file upstream issue with logs/minimal repro.
3) Keep validation gated via `REQUIRE_MUTAGEN=1` until upstream fix is confirmed stable.

## Files to review
- `scripts/setup_mutagen_host.sh`
- `scripts/verify_mutagen.sh`
- `scripts/verify_devcontainer.sh` (Mutagen hook)
- `docs/mutagen-validation.md`, `docs/mutagen-research.md`, `PROJECT_PLAN.md`
- Log: `/tmp/mutagen_ssh_invocations.log`
