# Auto-Update Setup for DevContainer and GitHub CLI

This setup ensures both your MacBook and remote hosts always have the latest versions of:
- GitHub CLI (`gh`)
- DevContainer CLI (`@devcontainers/cli`)

## Architecture: macOS-Centric Approach

**Primary Strategy**: Use macOS launchd as the single scheduler, with SSH remote execution for Linux servers.
- ✅ Single scheduler to manage (macOS only)
- ✅ No changes required on remote Linux servers
- ✅ Configuration stored in GitHub repository
- ✅ Automatic remote updates via SSH

## Quick Setup (macOS-Centric)

### Step 1: Sync launchd Configuration from Repository

```bash
# Sync launchd configuration from repo to system
./scripts/schedulers/sync_launchd.sh

# Optional: Enable RunAtLoad (disabled by default to prevent flooding)
./scripts/schedulers/sync_launchd.sh --enable-startup
```

### Step 2: Configure Remote Hosts (Optional)

```bash
# Create remote hosts configuration
mkdir -p ~/.slotmap
echo "c0802s4.ny5" > ~/.slotmap/remote-hosts.conf
# Add more hosts, one per line
```

### Step 3: Load and Start

```bash
# Load the launchd agent
launchctl load ~/Library/LaunchAgents/com.slotmap.toolupdate.plist

# Run immediately (or wait for 9:00 AM daily schedule)
launchctl start com.slotmap.toolupdate

# Monitor logs
tail -f /tmp/slotmap-toolupdate.log
```

## Manual Setup Options

### MacBook Only (No Remote Updates)

```bash
# 1. Initial tool setup (one-time)
./scripts/update_tools_mac.sh
source ~/.zshrc

# 2. Sync and load launchd configuration
./scripts/schedulers/sync_launchd.sh
launchctl load ~/Library/LaunchAgents/com.slotmap.toolupdate.plist

# 3. Verify it's running
launchctl list | grep slotmap
```

### Remote Host (DEFERRED - May Not Be Needed)

**Note**: systemd setup on remote hosts is currently deferred. The macOS launchd handles remote updates via SSH.

If you need local scheduling on Linux servers later:
```bash
# This is DEFERRED and may not be implemented
# The macOS-centric approach handles remote updates via SSH
# See scripts/schedulers/ for systemd files if needed in the future
```

## How It Works

### Version Detection
- **Primary method**: Uses `gh` CLI to query GitHub API for latest releases
- **Fallback method**: Uses `curl` if `gh` is not installed
- **Always gets latest**: Queries `devcontainers/cli` and `cli/cli` repos

### Installation Methods

#### MacBook (Homebrew)
- `gh` CLI: Installed/updated via Homebrew
- `devcontainer` CLI: Installed via npm to `~/.npm-global`
- No sudo required

#### Remote Host (Ubuntu/Debian)
- `gh` CLI: Downloaded to `~/.local/bin` (no sudo)
- `devcontainer` CLI: Installed via npm to `~/.npm-global`
- No sudo required

### Deployment Script Integration
The `run_local_devcontainer.sh` script now:
1. Queries GitHub for latest devcontainer CLI version
2. Auto-configures npm to use user directory if needed
3. Installs/updates to latest version automatically
4. Falls back gracefully if update fails

## Manual Commands

### Check Current Versions
```bash
# GitHub CLI
gh --version

# DevContainer CLI
devcontainer --version

# npm prefix (should be ~/.npm-global)
npm config get prefix
```

### Force Update to Latest
```bash
# On MacBook
./scripts/update_tools_mac.sh

# On Remote
./scripts/update_tools_remote.sh

# Or use the unified script (works on both)
./scripts/auto_update_tools.sh
```

### Override Version (if needed)
```bash
# Force specific devcontainer version
DEVCONTAINER_CLI_VERSION=0.80.1 ./scripts/deploy_remote_devcontainer.sh

# Skip updates entirely
SKIP_DEVCONTAINER_UPGRADE=1 ./scripts/deploy_remote_devcontainer.sh
```

## Benefits

1. **Always Latest**: Both tools stay current with latest features and fixes
2. **No Sudo Required**: Everything installs to user directories
3. **Automatic**: Can be scheduled to run daily
4. **Fallback Safe**: Works even if GitHub API is unavailable
5. **Cross-Platform**: Works on macOS (Homebrew) and Linux

## Modern Scheduling Systems

### Why Not Crontab?

While crontab still works, modern systems provide better alternatives:

#### **launchd (macOS)**
- ✅ Native macOS scheduler since OS X 10.4
- ✅ Better integration with system events
- ✅ Automatic restart on failure
- ✅ Power-aware (won't drain battery)
- ✅ GUI tools available (LaunchControl)

#### **systemd timers (Linux)**
- ✅ Standard on modern Linux (Ubuntu 16.04+, RHEL 7+, Debian 8+)
- ✅ Better logging with journald
- ✅ Dependency management
- ✅ Persistent timers (runs missed jobs)
- ✅ More flexible scheduling options

### Monitoring Scheduled Updates

#### macOS (launchd)
```bash
# View scheduled jobs
launchctl list | grep slotmap

# Check last run time and next run
launchctl print gui/$(id -u)/com.slotmap.toolupdate

# View logs
tail -f /tmp/slotmap-toolupdate.log

# Run manually
launchctl start com.slotmap.toolupdate

# Disable temporarily
launchctl unload ~/Library/LaunchAgents/com.slotmap.toolupdate.plist

# Re-enable
launchctl load ~/Library/LaunchAgents/com.slotmap.toolupdate.plist
```

#### Linux (systemd)
```bash
# View timer status and next run time
systemctl --user status slotmap-toolupdate.timer

# View service logs
journalctl --user -u slotmap-toolupdate.service -f

# List all timers
systemctl --user list-timers

# Run manually
systemctl --user start slotmap-toolupdate.service

# Disable temporarily
systemctl --user stop slotmap-toolupdate.timer

# Re-enable
systemctl --user start slotmap-toolupdate.timer
```

## Troubleshooting

### npm Permission Issues
```bash
# Fix npm to use user directory
npm config set prefix ~/.npm-global
mkdir -p ~/.npm-global/bin
echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.bashrc
source ~/.bashrc
```

### GitHub CLI Authentication
```bash
# Authenticate gh CLI (for API access)
gh auth login
```

### PATH Issues
```bash
# Ensure tools are in PATH
# MacBook
echo $PATH | grep -q ".npm-global" || echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.zshrc

# Linux
echo $PATH | grep -q ".npm-global" || echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.bashrc
echo $PATH | grep -q ".local/bin" || echo 'export PATH=~/.local/bin:$PATH' >> ~/.bashrc
```