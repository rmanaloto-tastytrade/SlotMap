# Scheduler Implementation Technical Guide

## Overview

This document details the technical implementation of the **macOS-centric scheduler approach** for the SlotMap project's automatic tool update system, using launchd with SSH remote execution.

## Architecture Design (macOS-Centric)

### Component Diagram
```
┌─────────────────────────────────────────────────────────┐
│                  macOS (Control Center)                  │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌────────────────────────────────────────────────┐    │
│  │                launchd (PRIMARY)                │    │
│  │  ┌──────────────────────────────────────────┐  │    │
│  │  │  com.slotmap.toolupdate.plist           │  │    │
│  │  │  - Daily @ 9:00 AM                      │  │    │
│  │  │  - RunAtLoad: false (default)           │  │    │
│  │  └────────────────┬─────────────────────────┘  │    │
│  └───────────────────┼─────────────────────────────┘    │
│                      ▼                                  │
│         ┌────────────────────────────┐                  │
│         │ update_tools_with_remotes.sh│                  │
│         └────────────┬───────────────┘                  │
│                      │                                  │
│        ┌─────────────┼─────────────┐                    │
│        ▼                           ▼                    │
│  ┌──────────┐              ┌──────────────┐            │
│  │  Local   │              │  SSH Remote  │            │
│  │  Update  │              │   Execution  │            │
│  └────┬─────┘              └───────┬──────┘            │
│       │                            │                    │
│       ▼                            ▼                    │
│  ┌──────────┐              ┌──────────────┐            │
│  │ Homebrew │              │  Remote Host │            │
│  │ npm local│              │  (c0802s4)   │            │
│  └──────────┘              └──────────────┘            │
│                                                         │
└─────────────────────────────────────────────────────────┘

Remote Linux Servers (DEFERRED systemd):
┌─────────────────────────────────────────────────────────┐
│                    Linux Server                          │
│  ┌─────────────────────────────────────────────────┐   │
│  │  systemd configuration DEFERRED                  │   │
│  │  - Not currently deployed                        │   │
│  │  - Updates handled via SSH from macOS           │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

## Implementation Details

### 1. Platform Detection Logic

```bash
# Pseudocode for OS detection
if [[ "$OSTYPE" == "darwin"* ]]; then
    PLATFORM="macos"
    SCHEDULER="launchd"
    CONFIG_DIR="$HOME/Library/LaunchAgents"
elif [[ -d /run/systemd/system ]]; then
    PLATFORM="linux"
    SCHEDULER="systemd"
    CONFIG_DIR="$HOME/.config/systemd/user"
else
    PLATFORM="linux-legacy"
    SCHEDULER="cron"
    CONFIG_DIR="/etc/cron.d"
fi
```

**References**:
- Bash Manual: Parameter Expansion [1]
- systemd Detection Best Practices [2]

### 2. launchd Implementation (macOS)

#### Configuration Structure
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Key Components -->
    <key>Label</key>
    <string>com.slotmap.toolupdate</string>

    <key>ProgramArguments</key>
    <array><!-- Command to execute --></array>

    <key>StartCalendarInterval</key>
    <dict><!-- Schedule configuration --></dict>

    <key>EnvironmentVariables</key>
    <dict><!-- Environment setup --></dict>
</dict>
</plist>
```

#### Key Features Used
1. **StartCalendarInterval**: Precise scheduling without cron syntax
2. **RunAtLoad**: Execute on system startup
3. **Nice**: Process priority management
4. **StandardOutPath/StandardErrorPath**: Native logging
5. **EnvironmentVariables**: Complete environment control

**Technical References**:
- Apple Developer: Creating Launch Daemons and Agents [3]
- launchd.plist(5) man page [4]

### 3. systemd Implementation (Linux)

#### Service Unit Structure
```ini
[Unit]
Description=SlotMap Tool Update Service
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/path/to/script
User=%u
Environment="PATH=/usr/local/bin:/usr/bin:/bin"

# Security Hardening
PrivateTmp=true
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=read-only

[Install]
WantedBy=default.target
```

#### Timer Unit Structure
```ini
[Unit]
Description=SlotMap Tool Update Timer
Requires=slotmap-toolupdate.service

[Timer]
OnCalendar=daily
OnCalendar=09:00:00
OnBootSec=5min
Persistent=true
RandomizedDelaySec=30min

[Install]
WantedBy=timers.target
```

#### Key Features Used
1. **Persistent**: Catches up missed runs
2. **RandomizedDelaySec**: Prevents thundering herd
3. **OnBootSec**: Startup execution
4. **Security Hardening**: Namespace isolation
5. **Journal Integration**: Structured logging

**Technical References**:
- systemd.service(5) man page [5]
- systemd.timer(5) man page [6]
- systemd Security Features [7]

### 4. Version Detection Implementation

#### GitHub API Integration
```bash
get_latest_github_release() {
    local repo=$1

    # Method 1: Using gh CLI (authenticated)
    if command -v gh &>/dev/null; then
        gh api "repos/${repo}/releases/latest" \
            --jq '.tag_name' 2>/dev/null | sed 's/^v//'

    # Method 2: Using curl (unauthenticated)
    else
        curl -s "https://api.github.com/repos/${repo}/releases/latest" \
            | grep '"tag_name":' \
            | sed -E 's/.*"([^"]+)".*/\1/' \
            | sed 's/^v//'
    fi
}
```

**API Rate Limits**:
- Unauthenticated: 60 requests/hour
- Authenticated: 5000 requests/hour
- Reference: GitHub API Documentation [8]

#### npm Registry Integration
```bash
get_latest_npm_version() {
    local package=$1
    npm view "${package}" version 2>/dev/null
}
```

**Registry Endpoints**:
- Public: https://registry.npmjs.org/
- Scoped: https://registry.npmjs.org/@scope%2Fpackage
- Reference: npm Registry API [9]

### 5. User-Level npm Configuration

#### Problem Statement
- System npm prefix `/usr/lib` requires sudo
- User cannot write to system directories
- Need isolated, user-controlled environment

#### Solution Implementation
```bash
configure_user_npm() {
    local npm_prefix=$(npm config get prefix)

    if [[ "$npm_prefix" == "/usr" ]] || [[ "$npm_prefix" == "/usr/local" ]]; then
        npm config set prefix "$HOME/.npm-global"
        mkdir -p "$HOME/.npm-global/bin"
        export PATH="$HOME/.npm-global/bin:$PATH"

        # Persist to shell profile
        local shell_profile
        [[ "$SHELL" == */zsh ]] && shell_profile=".zshrc" || shell_profile=".bashrc"

        if ! grep -q ".npm-global/bin" "$HOME/$shell_profile"; then
            echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> "$HOME/$shell_profile"
        fi
    fi
}
```

**References**:
- npm Documentation: Resolving EACCES permissions errors [10]
- Node.js Best Practices [11]

## Security Analysis

### Threat Model

| Threat | Mitigation | Implementation |
|--------|------------|----------------|
| Privilege Escalation | Run as user, not root | User-level configs only |
| Command Injection | Quote all variables | `"${var}"` pattern |
| Path Traversal | Absolute paths only | No relative paths |
| Supply Chain Attack | Verify sources | Use official APIs |
| Resource Exhaustion | Nice values, limits | Nice=10, timeouts |
| Information Disclosure | Secure logging | No sensitive data logged |

### Security Features by Platform

#### launchd Security
- Runs in user context
- macOS sandbox compatible
- Gatekeeper/notarization aware
- XPC service isolation support

#### systemd Security
- Namespace isolation (PrivateTmp=true)
- Capability dropping (NoNewPrivileges=true)
- Filesystem protection (ProtectSystem=strict)
- Resource limits via cgroups

**Security References**:
- OWASP Secure Coding Practices [12]
- CIS Benchmarks for macOS/Linux [13]

## Performance Optimization

### Resource Usage Analysis

| Component | CPU Usage | Memory | Disk I/O | Network |
|-----------|-----------|--------|----------|---------|
| Scheduler | <0.1% | <10MB | Minimal | None |
| Update Script | <1% | <50MB | <10MB | <1MB |
| npm install | <5% | <200MB | Variable | Variable |

### Optimization Techniques

1. **Nice Values**: Low priority execution
2. **Randomized Delays**: Prevent load spikes
3. **Caching**: Reuse API responses
4. **Conditional Updates**: Only update if version differs
5. **Parallel Operations**: When safe

**Performance References**:
- Linux Performance Tuning [14]
- macOS Performance Guidelines [15]

## Testing Strategy

### Unit Tests
```bash
# Test version detection
test_version_detection() {
    local version=$(get_latest_github_release "devcontainers/cli")
    [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
}

# Test platform detection
test_platform_detection() {
    local platform=$(detect_platform)
    [[ "$platform" == "macos" || "$platform" == "linux" ]] || return 1
}
```

### Integration Tests
1. Schedule installation
2. Manual trigger
3. Log verification
4. Update verification
5. Rollback testing

### Load Testing
- Simulate API rate limits
- Test with slow networks
- Verify timeout handling

**Testing References**:
- Bash Testing Frameworks [16]
- CI/CD Best Practices [17]

## Monitoring and Observability

### Metrics to Track
1. **Execution Metrics**
   - Success/failure rate
   - Execution duration
   - Resource usage

2. **Update Metrics**
   - Version changes
   - Update frequency
   - Failure reasons

3. **System Metrics**
   - Scheduler health
   - Log volume
   - Error patterns

### Log Analysis

#### launchd Logs
```bash
# View recent logs
log show --predicate 'processImagePath contains "slotmap"' --last 1h

# Stream logs
log stream --predicate 'processImagePath contains "slotmap"'
```

#### systemd Logs
```bash
# View service logs
journalctl --user -u slotmap-toolupdate.service

# Follow logs
journalctl --user -u slotmap-toolupdate.service -f

# Export for analysis
journalctl --user -u slotmap-toolupdate.service --output=json
```

**Monitoring References**:
- Prometheus Best Practices [18]
- ELK Stack Documentation [19]

## Rollback Procedures

### Scheduler Removal

#### macOS
```bash
launchctl unload ~/Library/LaunchAgents/com.slotmap.toolupdate.plist
rm ~/Library/LaunchAgents/com.slotmap.toolupdate.plist
```

#### Linux
```bash
systemctl --user disable --now slotmap-toolupdate.timer
rm ~/.config/systemd/user/slotmap-toolupdate.*
systemctl --user daemon-reload
```

### Version Rollback
```bash
# Specific version installation
npm install -g @devcontainers/cli@0.80.1

# gh CLI downgrade (macOS)
brew install gh@2.35.0

# gh CLI downgrade (Linux)
# Download specific version from GitHub releases
```

## Migration Guide

### From crontab to Modern Schedulers

#### Step 1: Export Existing Crontab
```bash
crontab -l > ~/old_crontab.txt
```

#### Step 2: Convert to Modern Format
| Cron Expression | launchd | systemd |
|----------------|---------|---------|
| `0 9 * * *` | `<key>Hour</key><integer>9</integer>` | `OnCalendar=09:00:00` |
| `@reboot` | `<key>RunAtLoad</key><true/>` | `OnBootSec=0` |
| `*/30 * * * *` | Use StartInterval | `OnCalendar=*:0/30` |

#### Step 3: Install New Scheduler
```bash
./scripts/schedulers/install_scheduler.sh
```

#### Step 4: Verify Operation
```bash
# macOS
launchctl list | grep slotmap

# Linux
systemctl --user list-timers
```

#### Step 5: Remove Old Crontab
```bash
crontab -r  # Remove after verification
```

## Troubleshooting Guide

### Common Issues and Solutions

| Issue | Platform | Solution |
|-------|----------|----------|
| Job not running | macOS | Check `launchctl list`, verify plist syntax |
| Job not running | Linux | Check `systemctl --user status`, verify timer |
| Permission denied | Both | Ensure user-level installation |
| Environment issues | Both | Explicitly set PATH and variables |
| API rate limits | Both | Implement caching, use authentication |

### Debug Commands

```bash
# macOS debug
launchctl print gui/$(id -u)/com.slotmap.toolupdate
plutil -lint ~/Library/LaunchAgents/com.slotmap.toolupdate.plist

# Linux debug
systemd-analyze verify --user slotmap-toolupdate.service
journalctl --user -u slotmap-toolupdate.service -xe
```

## Future Enhancements

### Planned Improvements
1. **Webhook Integration**: GitHub webhook for instant updates
2. **Metrics Dashboard**: Grafana dashboard for monitoring
3. **Multi-Tool Support**: Extend beyond gh/devcontainer
4. **Configuration Management**: YAML/TOML configuration
5. **Notification System**: Slack/email notifications

### Research Areas
1. **Container Scheduling**: Kubernetes CronJob integration
2. **Cloud Functions**: Serverless scheduling options
3. **Service Mesh**: Istio/Linkerd integration
4. **GitOps**: ArgoCD/Flux integration

## References

[1] GNU Bash Manual - Parameter Expansion. https://www.gnu.org/software/bash/manual/

[2] systemd Project - Detecting systemd. https://www.freedesktop.org/software/systemd/

[3] Apple Developer - Creating Launch Daemons and Agents. 2023.

[4] launchd.plist(5) - macOS Manual Pages.

[5] systemd.service(5) - Linux Manual Pages.

[6] systemd.timer(5) - Linux Manual Pages.

[7] systemd Security Features. https://systemd.io/SECURITY/

[8] GitHub API Documentation - Rate Limiting. 2024.

[9] npm Registry API Documentation. 2024.

[10] npm Docs - Resolving EACCES permissions errors. 2024.

[11] Node.js Best Practices Repository. https://github.com/goldbergyoni/nodebestpractices

[12] OWASP Secure Coding Practices - Quick Reference Guide. 2023.

[13] CIS Benchmarks. https://www.cisecurity.org/cis-benchmarks/

[14] Brendan Gregg - Linux Performance. http://www.brendangregg.com/

[15] Apple - Performance Guidelines. 2023.

[16] Bash Automated Testing System (BATS). https://github.com/bats-core/bats-core

[17] CI/CD Best Practices - CNCF. 2023.

[18] Prometheus Best Practices. https://prometheus.io/docs/practices/

[19] Elastic Stack Documentation. 2024.

## Appendices

### Appendix A: Complete Script Listings
- See `/scripts/schedulers/` directory

### Appendix B: Configuration Templates
- launchd: `/scripts/schedulers/com.slotmap.toolupdate.plist`
- systemd: `/scripts/schedulers/slotmap-toolupdate.service`
- systemd: `/scripts/schedulers/slotmap-toolupdate.timer`

### Appendix C: Test Cases
- Platform detection tests
- Version detection tests
- Scheduler installation tests
- Update execution tests

## Document Metadata

- **Version**: 1.0.0
- **Date**: November 23, 2024
- **Author**: SlotMap Development Team
- **Review Status**: Complete
- **Classification**: Technical Documentation