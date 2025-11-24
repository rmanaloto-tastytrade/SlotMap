# Modern Scheduler Configuration

This directory contains modern scheduling configurations for automatic tool updates, replacing traditional crontab with platform-native solutions.

## Files

### macOS (launchd)
- `com.slotmap.toolupdate.plist` - launchd agent configuration
  - Runs daily at 9:00 AM
  - Runs at system startup
  - Logs to `/tmp/slotmap-toolupdate.log`

### Linux (systemd)
- `slotmap-toolupdate.service` - systemd service unit
  - Defines the update task
  - User-level service (no sudo)
  - Security hardening enabled
- `slotmap-toolupdate.timer` - systemd timer unit
  - Schedules the service
  - Daily at 9:00 AM + random delay
  - Persistent (runs missed jobs)

### Installation
- `install_scheduler.sh` - Universal installer
  - Auto-detects OS
  - Installs appropriate scheduler
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