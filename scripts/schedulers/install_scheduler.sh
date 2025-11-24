#!/usr/bin/env bash
set -euo pipefail

# Install scheduler for automatic tool updates
echo "=== Installing Tool Update Scheduler ==="

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS - Install launchd agent
  echo "Platform: macOS - Installing launchd agent..."

  PLIST_SRC="$(dirname "$0")/com.slotmap.toolupdate.plist"
  PLIST_DEST="$HOME/Library/LaunchAgents/com.slotmap.toolupdate.plist"

  # Create LaunchAgents directory if it doesn't exist
  mkdir -p "$HOME/Library/LaunchAgents"

  # Copy plist file
  cp "$PLIST_SRC" "$PLIST_DEST"

  # Load the agent
  launchctl load "$PLIST_DEST" 2>/dev/null || {
    echo "Agent already loaded, reloading..."
    launchctl unload "$PLIST_DEST"
    launchctl load "$PLIST_DEST"
  }

  echo "✅ launchd agent installed and loaded"
  echo ""
  echo "Commands:"
  echo "  View status:  launchctl list | grep slotmap"
  echo "  View logs:    tail -f /tmp/slotmap-toolupdate.log"
  echo "  Run now:      launchctl start com.slotmap.toolupdate"
  echo "  Disable:      launchctl unload ~/Library/LaunchAgents/com.slotmap.toolupdate.plist"

else
  # Linux - Install systemd timer
  echo "Platform: Linux - Installing systemd timer..."

  SERVICE_SRC="$(dirname "$0")/slotmap-toolupdate.service"
  TIMER_SRC="$(dirname "$0")/slotmap-toolupdate.timer"
  SYSTEMD_USER_DIR="$HOME/.config/systemd/user"

  # Create systemd user directory if it doesn't exist
  mkdir -p "$SYSTEMD_USER_DIR"

  # Copy service and timer files
  cp "$SERVICE_SRC" "$SYSTEMD_USER_DIR/"
  cp "$TIMER_SRC" "$SYSTEMD_USER_DIR/"

  # Reload systemd daemon
  systemctl --user daemon-reload

  # Enable and start the timer
  systemctl --user enable slotmap-toolupdate.timer
  systemctl --user start slotmap-toolupdate.timer

  echo "✅ systemd timer installed and started"
  echo ""
  echo "Commands:"
  echo "  View status:  systemctl --user status slotmap-toolupdate.timer"
  echo "  View logs:    journalctl --user -u slotmap-toolupdate.service -f"
  echo "  Run now:      systemctl --user start slotmap-toolupdate.service"
  echo "  Disable:      systemctl --user disable slotmap-toolupdate.timer"
fi

echo ""
echo "The tool updater will run:"
echo "  - Daily at 9:00 AM"
echo "  - On system startup (after 5 minutes)"
echo ""
echo "Next scheduled run:"
if [[ "$OSTYPE" == "darwin"* ]]; then
  launchctl list | grep slotmap || echo "Run 'launchctl start com.slotmap.toolupdate' to test"
else
  systemctl --user list-timers slotmap-toolupdate.timer --no-pager
fi