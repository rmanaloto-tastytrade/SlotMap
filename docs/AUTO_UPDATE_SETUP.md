# Auto-Update Setup for DevContainer and GitHub CLI

This setup ensures both your MacBook and remote hosts always have the latest versions of:
- GitHub CLI (`gh`)
- DevContainer CLI (`@devcontainers/cli`)

## Quick Setup

### On MacBook

```bash
# 1. Initial setup (one-time)
./scripts/update_tools_mac.sh
source ~/.zshrc

# 2. Schedule daily updates (optional)
# Add to crontab (runs daily at 2 AM)
(crontab -l 2>/dev/null; echo "0 2 * * * cd ~/dev/github/SergeyMakeev/SlotMap-security-test && ./scripts/auto_update_tools.sh > /tmp/tool_update.log 2>&1") | crontab -

# Or use launchd (macOS native scheduler)
# Create ~/Library/LaunchAgents/com.slotmap.toolupdate.plist with the schedule
```

### On Remote Host (c0802s4.ny5)

```bash
# 1. Initial setup (one-time)
ssh c0802s4.ny5
cd ~/dev/github/SlotMap
./scripts/update_tools_remote.sh
source ~/.bashrc

# 2. Schedule daily updates (optional)
(crontab -l 2>/dev/null; echo "0 2 * * * cd ~/dev/github/SlotMap && ./scripts/auto_update_tools.sh > /tmp/tool_update.log 2>&1") | crontab -
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