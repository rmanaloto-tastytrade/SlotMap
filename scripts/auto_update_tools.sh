#!/usr/bin/env bash
set -euo pipefail

# Auto-update script that can be scheduled via cron/launchd
# Keeps gh CLI and devcontainer CLI always up-to-date

echo "=== Auto-Update Development Tools ==="
echo "Date: $(date)"
echo "Host: $(hostname)"

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS
  echo "Platform: macOS"
  "$(dirname "$0")/update_tools_mac.sh"
else
  # Linux/Remote
  echo "Platform: Linux"
  "$(dirname "$0")/update_tools_remote.sh"
fi

echo ""
echo "=== Update Complete ==="

# Optional: Log to file for cron/scheduled runs
# echo "$(date): Tools updated" >> ~/.tool_updates.log