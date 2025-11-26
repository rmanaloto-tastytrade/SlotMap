#!/usr/bin/env bash
set -euo pipefail

# Update tools locally and on configured remote hosts via SSH
# This script is designed to be run from macOS launchd

echo "=== Tool Update Orchestrator ==="
echo "Date: $(date)"
echo "Host: $(hostname)"

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${HOME}/Library/Logs/SlotMap"
mkdir -p "$LOG_DIR"

# Remote hosts to update (can be configured via environment or config file)
# Leave empty to skip remote updates
REMOTE_HOSTS="${SLOTMAP_REMOTE_HOSTS:-}"

# Example: SLOTMAP_REMOTE_HOSTS="your-remote-host.example.com"
# Or read from config file if it exists
CONFIG_FILE="${HOME}/.slotmap/remote-hosts.conf"
if [[ -z "$REMOTE_HOSTS" ]] && [[ -f "$CONFIG_FILE" ]]; then
    REMOTE_HOSTS=$(grep -v '^#' "$CONFIG_FILE" 2>/dev/null | tr '\n' ' ' || true)
fi

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_DIR/toolupdate.log"
}

# Function to update remote host
update_remote_host() {
    local host=$1
    log "Updating remote host: $host"

    # Check if host is reachable
    if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "$host" true 2>/dev/null; then
        log "WARNING: Cannot reach $host, skipping"
        return 1
    fi

    # Check if remote has the update script
    if ssh "$host" "test -f ~/dev/github/SlotMap/scripts/update_tools_remote.sh" 2>/dev/null; then
        log "Running update on $host..."
        if ssh "$host" "cd ~/dev/github/SlotMap && git pull origin security-fixes-phase1 && ./scripts/update_tools_remote.sh" 2>&1 | tee -a "$LOG_DIR/remote-$host.log"; then
            log "SUCCESS: Updated tools on $host"
        else
            log "ERROR: Failed to update tools on $host"
            return 1
        fi
    else
        log "INFO: Update script not found on $host, attempting to set up..."

        # Try to clone and setup if not present
        if ssh "$host" "mkdir -p ~/dev/github && cd ~/dev/github && [ ! -d SlotMap ] && git clone https://github.com/rmanaloto-tastytrade/SlotMap.git && cd SlotMap && git checkout security-fixes-phase1" 2>/dev/null; then
            log "Repository cloned on $host, running initial setup..."
            ssh "$host" "cd ~/dev/github/SlotMap && ./scripts/update_tools_remote.sh" 2>&1 | tee -a "$LOG_DIR/remote-$host.log"
        else
            log "INFO: Repository already exists or cannot be cloned on $host"
        fi
    fi

    return 0
}

# Main execution
log "Starting tool update orchestration"

# Step 1: Update local macOS tools
log "Updating local macOS tools..."
if "$SCRIPT_DIR/update_tools_mac.sh" 2>&1 | tee -a "$LOG_DIR/local.log"; then
    log "SUCCESS: Local tools updated"
else
    log "ERROR: Local tool update failed"
fi

# Step 2: Update remote hosts (if configured)
if [[ -n "$REMOTE_HOSTS" ]]; then
    log "Remote hosts configured: $REMOTE_HOSTS"

    for host in $REMOTE_HOSTS; do
        # Skip empty entries
        [[ -z "$host" ]] && continue

        # Run remote updates in background to handle multiple hosts
        update_remote_host "$host" &
    done

    # Wait for all background jobs to complete
    wait
    log "All remote updates completed"
else
    log "No remote hosts configured for updates"
    log "To enable remote updates, either:"
    log "  1. Set SLOTMAP_REMOTE_HOSTS environment variable"
    log "  2. Create ~/.slotmap/remote-hosts.conf with one host per line"
fi

# Step 3: Summary
log "=== Update Summary ==="
log "Local tools: $(devcontainer --version 2>/dev/null || echo 'not installed')"
log "GitHub CLI: $(gh --version 2>/dev/null | head -1 || echo 'not installed')"

# Check remote versions if hosts configured
if [[ -n "$REMOTE_HOSTS" ]]; then
    for host in $REMOTE_HOSTS; do
        [[ -z "$host" ]] && continue
        log "Remote $host:"
        ssh -o ConnectTimeout=5 "$host" "devcontainer --version 2>/dev/null || echo '  devcontainer: not installed'" 2>/dev/null || echo "  unreachable"
        ssh -o ConnectTimeout=5 "$host" "gh --version 2>/dev/null | head -1 || echo '  gh: not installed'" 2>/dev/null || true
    done
fi

log "Tool update orchestration complete"

# Rotate logs if they get too large (>10MB)
find "$LOG_DIR" -name "*.log" -size +10M -exec mv {} {}.old \; -exec touch {} \;

exit 0