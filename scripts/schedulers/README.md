# Modern Scheduler Configuration

This directory contains modern scheduling configurations for automatic tool updates, using a **macOS-centric approach** with SSH remote execution.

## Architecture: macOS-Centric with Remote SSH

**Primary Strategy**: Use macOS launchd as the single scheduler, executing updates on remote Linux servers via SSH.
- Single point of control (macOS)
- No systemd changes required on remote servers
- Configuration stored in GitHub repository
- Automatic syncing via `sync_launchd.sh`

## Files

### macOS (launchd) - PRIMARY
- `com.slotmap.toolupdate.plist` - launchd agent configuration
  - Runs daily at 9:00 AM
  - RunAtLoad DISABLED by default (prevents flooding)
  - Executes `update_tools_with_remotes.sh`
  - Logs to `/tmp/slotmap-toolupdate.log`
- `sync_launchd.sh` - Syncs plist from repo to system
  - Validates configuration
  - Creates backups
  - Manages RunAtLoad setting
- `update_tools_with_remotes.sh` - Orchestrator script
  - Updates local Mac tools
  - SSH executes updates on remote hosts
  - Handles connectivity failures gracefully

### Linux (systemd) - DEFERRED
- `slotmap-toolupdate.service` - systemd service unit (NOT DEPLOYED)
- `slotmap-toolupdate.timer` - systemd timer unit (NOT DEPLOYED)
- **Note**: These files exist for future use if needed, but are not currently deployed

### Installation
- `install_scheduler.sh` - Universal installer
  - Auto-detects OS
  - On macOS: Installs launchd configuration
  - On Linux: DEFERRED - not currently used
  - No sudo required

## Why Modern Schedulers?

### Problems with Crontab
- ❌ No dependency management
- ❌ Limited logging
- ❌ No automatic restart on failure
- ❌ Can't handle missed jobs
- ❌ No integration with system events
- ❌ Requires manual PATH setup

### Benefits of launchd (macOS)
- ✅ Native to macOS since 10.4
- ✅ Power management aware
- ✅ Automatic restart on failure
- ✅ Rich logging
- ✅ GUI management tools available
- ✅ Integrates with system events

### Benefits of systemd (Linux)
- ✅ Standard on all modern Linux
- ✅ Centralized logging with journald
- ✅ Dependency management
- ✅ Resource limits and security
- ✅ Persistent timers
- ✅ More scheduling options

## Usage

### Quick Install
```bash
./install_scheduler.sh
```

### Manual Install

#### macOS
```bash
cp com.slotmap.toolupdate.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.slotmap.toolupdate.plist
```

#### Linux
```bash
cp slotmap-toolupdate.* ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now slotmap-toolupdate.timer
```

### Management Commands

#### macOS
```bash
# Status
launchctl list | grep slotmap

# Logs
tail -f /tmp/slotmap-toolupdate.log

# Run now
launchctl start com.slotmap.toolupdate

# Stop
launchctl unload ~/Library/LaunchAgents/com.slotmap.toolupdate.plist
```

#### Linux
```bash
# Status
systemctl --user status slotmap-toolupdate.timer

# Logs
journalctl --user -u slotmap-toolupdate -f

# Run now
systemctl --user start slotmap-toolupdate.service

# Stop
systemctl --user stop slotmap-toolupdate.timer
```

## Security Notes

- All configurations run as user (no root/sudo)
- macOS: Uses nice value 10 (low priority)
- Linux: Includes security hardening (PrivateTmp, NoNewPrivileges)
- Logs are written to user-accessible locations
- No sensitive data in configurations