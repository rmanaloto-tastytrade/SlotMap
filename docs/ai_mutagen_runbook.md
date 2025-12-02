# AI Agent Runbook — Mutagen + Remote Devcontainer

Goal: enable an AI agent to diagnose and fix Mutagen sync from macOS to the remote Linux devcontainer (workspace mounted at `/home/<DEVCONTAINER_USER>/workspace`, sshd on container port 2222 forwarded to host `127.0.0.1:${DEVCONTAINER_SSH_PORT:-9222}`).

## Current state
- Mutagen expected version: `0.18.1` (pinned in `.devcontainer/Dockerfile` and checked in `scripts/verify_devcontainer.sh`).
- Known blocker (reproducible without explicit ssh config): `mutagen sync create` launches the agent with hostname literal `ssh`, causing `ssh: Could not resolve hostname ssh` even though plain SSH works. Minimal repro: `mutagen sync create /tmp/foo ssh://localhost/tmp`.
- SSH/Mutagen wiring exists but validation is optional: `scripts/verify_devcontainer.sh` only runs Mutagen when `REQUIRE_MUTAGEN=1`. Host-side setup must write `~/.mutagen.yml` with `sync.ssh.command` and `sync.ssh.path` (done by `scripts/setup_mutagen_host.sh`) so the host argument is not clobbered.

## Files to review first
- `.devcontainer/devcontainer.json` — SSH port exposure and workspace mount.
- `.devcontainer/Dockerfile` — Mutagen install block (search `MUTAGEN_VERSION`).
- `scripts/setup_mutagen_host.sh` — writes `~/.mutagen/cpp-devcontainer_ssh_config`, `~/.mutagen.yml`, ssh/scp wrappers, restarts daemon.
- `scripts/verify_mutagen.sh` — probe session (two-way-resolved) using the SSH alias/wrapper.
- `scripts/verify_devcontainer.sh` — optional Mutagen check gated by `REQUIRE_MUTAGEN`.
- `docs/mutagen-validation.md`, `docs/mutagen-ai-hand-off.md`, `docs/mutagen-research.md`, `docs/mutagen_sync.md` — status, repro, and context.
- `config/env/*.env` — host/user/port/key defaults for different targets.
- Log to inspect if present: `/tmp/mutagen_ssh_invocations.log` (written by the ssh wrapper).

## Expected happy path
1) macOS: `CONFIG_ENV_FILE=<env> scripts/setup_mutagen_host.sh` to generate SSH config/wrapper and restart the Mutagen daemon with the wrapper in PATH.
2) macOS: `CONFIG_ENV_FILE=<env> scripts/verify_mutagen.sh` (or `REQUIRE_MUTAGEN=1 scripts/verify_devcontainer.sh --require-ssh`) to create a temporary two-way session syncing `<repo>/.mutagen_probe` ↔ `/home/<CONTAINER_USER>/workspace/.mutagen_probe`.
3) `mutagen sync list --long <session>` reports `Status: Watching/Connected` with no retries/backoff/conflicts; probe files appear on both ends; session terminates and cleans probes.

## Debug/fix checklist
- Run `MUTAGEN_LOG_LEVEL=debug mutagen daemon run` in foreground with the ssh wrapper from `setup_mutagen_host.sh`, then rerun the probe to capture the exact ssh argv showing the host-as-`ssh` bug.
- Persist the ssh command by restarting the daemon with `MUTAGEN_SSH_COMMAND`/`MUTAGEN_SSH_PATH` pointing at the wrapper (`~/.mutagen/bin/ssh`) created by `scripts/setup_mutagen_host.sh`. The YAML global config only holds portable defaults; ssh command/path comes from the daemon environment.
- Try an alternate Mutagen version (e.g., 0.17.x or 0.19.x) to isolate regressions; keep container/host versions aligned.
- If still broken, prepare an upstream issue with logs and minimal repro.
- After a fix, enable `REQUIRE_MUTAGEN=1` in `scripts/verify_devcontainer.sh` for all envs to gate validation.
- Optional: add a small helper `scripts/mutagen_sync.sh` to wrap create/pause/resume/terminate with ignores derived from `CONFIG_ENV_FILE`.

## Prompt to give the AI agent
You are assisting on the SlotMap repo to make Mutagen work for macOS → remote devcontainer sync. Read `docs/ai_mutagen_runbook.md` and the referenced files before changing anything. Focus on the SSH host-as-`ssh` bug in Mutagen agent launches. Key files: `.devcontainer/devcontainer.json`, `.devcontainer/Dockerfile`, `scripts/setup_mutagen_host.sh`, `scripts/verify_mutagen.sh`, `scripts/verify_devcontainer.sh`, `docs/mutagen-validation.md`, `docs/mutagen-ai-hand-off.md`, `docs/mutagen-research.md`, `docs/mutagen_sync.md`, and `config/env/*.env`. Deliver a working two-way Mutagen session validated by `scripts/verify_mutagen.sh`, then enable `REQUIRE_MUTAGEN=1` in `scripts/verify_devcontainer.sh` once the bug is resolved.
