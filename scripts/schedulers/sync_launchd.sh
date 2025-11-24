#!/usr/bin/env bash
set -euo pipefail

# Sync launchd configuration from GitHub repository to macOS
# Modern best practices for keeping launchd in sync with version control

echo "=== LaunchD Sync Tool ==="
echo "Syncing launchd configuration from repository to system"

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLIST_FILE="com.slotmap.toolupdate.plist"
PLIST_SRC="${SCRIPT_DIR}/${PLIST_FILE}"
PLIST_DEST="${HOME}/Library/LaunchAgents/${PLIST_FILE}"
BACKUP_DIR="${HOME}/Library/LaunchAgents/backups"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
}

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    print_status "$RED" "ERROR: This script is for macOS only"
    exit 1
fi

# Check if plist exists in repository
if [[ ! -f "$PLIST_SRC" ]]; then
    print_status "$RED" "ERROR: Source plist not found: $PLIST_SRC"
    exit 1
fi

# Create LaunchAgents directory if it doesn't exist
mkdir -p "$HOME/Library/LaunchAgents"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Function to get plist status
get_plist_status() {
    if launchctl list | grep -q "com.slotmap.toolupdate"; then
        echo "loaded"
    else
        echo "not_loaded"
    fi
}

# Function to validate plist
validate_plist() {
    local plist=$1
    if plutil -lint "$plist" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Main sync logic
main() {
    local initial_status
    initial_status=$(get_plist_status)

    print_status "$YELLOW" "Current status: $initial_status"

    # Validate source plist
    if ! validate_plist "$PLIST_SRC"; then
        print_status "$RED" "ERROR: Source plist validation failed"
        plutil -lint "$PLIST_SRC"
        exit 1
    fi

    print_status "$GREEN" "✓ Source plist validated"

    # Check if destination exists and differs
    if [[ -f "$PLIST_DEST" ]]; then
        if ! diff -q "$PLIST_SRC" "$PLIST_DEST" >/dev/null 2>&1; then
            print_status "$YELLOW" "Differences detected between repository and system"

            # Create backup with timestamp
            local backup_file
            backup_file="${BACKUP_DIR}/${PLIST_FILE}.$(date +%Y%m%d_%H%M%S)"
            cp "$PLIST_DEST" "$backup_file"
            print_status "$GREEN" "✓ Backup created: $backup_file"

            # Unload if currently loaded
            if [[ "$initial_status" == "loaded" ]]; then
                print_status "$YELLOW" "Unloading current agent..."
                launchctl unload "$PLIST_DEST" 2>/dev/null || true
            fi

            # Copy new version
            cp "$PLIST_SRC" "$PLIST_DEST"
            print_status "$GREEN" "✓ Updated plist from repository"

            # Reload if was previously loaded
            if [[ "$initial_status" == "loaded" ]]; then
                print_status "$YELLOW" "Reloading agent..."
                launchctl load "$PLIST_DEST"
                print_status "$GREEN" "✓ Agent reloaded"
            fi
        else
            print_status "$GREEN" "✓ Already in sync with repository"
        fi
    else
        # First time installation
        print_status "$YELLOW" "Installing plist for first time..."
        cp "$PLIST_SRC" "$PLIST_DEST"
        print_status "$GREEN" "✓ Installed plist from repository"
    fi

    # Show current configuration
    echo ""
    print_status "$YELLOW" "=== Current Configuration ==="
    echo "Plist location: $PLIST_DEST"
    echo "Status: $(get_plist_status)"

    if [[ "$(get_plist_status)" == "loaded" ]]; then
        echo "Next run: $(launchctl print gui/$(id -u)/com.slotmap.toolupdate 2>/dev/null | grep -A1 "next fire date" | tail -1 || echo "Not scheduled")"
    fi

    # Provide management commands
    echo ""
    print_status "$YELLOW" "=== Management Commands ==="
    echo "To load agent:    launchctl load $PLIST_DEST"
    echo "To unload agent:  launchctl unload $PLIST_DEST"
    echo "To run now:       launchctl start com.slotmap.toolupdate"
    echo "To view logs:     tail -f /tmp/slotmap-toolupdate.log"
    echo "To view status:   launchctl list | grep slotmap"

    # Check for RunAtLoad setting
    if plutil -extract RunAtLoad raw "$PLIST_DEST" 2>/dev/null | grep -q "true"; then
        print_status "$YELLOW" "Note: RunAtLoad is enabled (runs on system startup)"
    else
        print_status "$GREEN" "Note: RunAtLoad is disabled (won't run on system startup)"
    fi

    # Clean up old backups (keep last 10)
    if [[ -d "$BACKUP_DIR" ]]; then
        local backup_count
        backup_count=$(find "$BACKUP_DIR" -name "${PLIST_FILE}.*" | wc -l)
        if [[ $backup_count -gt 10 ]]; then
            print_status "$YELLOW" "Cleaning old backups (keeping last 10)..."
            find "$BACKUP_DIR" -name "${PLIST_FILE}.*" | sort | head -n -10 | xargs rm
            print_status "$GREEN" "✓ Old backups cleaned"
        fi
    fi
}

# Option to enable/disable at startup
if [[ "${1:-}" == "--enable-startup" ]]; then
    print_status "$YELLOW" "Enabling RunAtLoad (will run on system startup)..."
    plutil -replace RunAtLoad -bool true "$PLIST_SRC"
    print_status "$GREEN" "✓ RunAtLoad enabled in repository"
elif [[ "${1:-}" == "--disable-startup" ]]; then
    print_status "$YELLOW" "Disabling RunAtLoad (won't run on system startup)..."
    plutil -replace RunAtLoad -bool false "$PLIST_SRC"
    print_status "$GREEN" "✓ RunAtLoad disabled in repository"
elif [[ "${1:-}" == "--help" ]]; then
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --enable-startup   Enable RunAtLoad (run on system startup)"
    echo "  --disable-startup  Disable RunAtLoad (default)"
    echo "  --help            Show this help message"
    echo ""
    echo "This script syncs the launchd plist from the repository to your system."
    exit 0
fi

# Run main sync
main

print_status "$GREEN" "✓ Sync complete!"