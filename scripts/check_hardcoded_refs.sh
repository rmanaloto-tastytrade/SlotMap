#!/usr/bin/env bash
set -euo pipefail

# Check for hardcoded hostnames and usernames that shouldn't be committed
# Run this before committing to catch accidental hardcoded references

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

echo "Checking for hardcoded hostnames and usernames..."

# Patterns to detect (adjust based on your environment)
PATTERNS=(
  # Internal hostname patterns (e.g., c0802s4.ny5)
  'c[0-9]+s[0-9]+\.ny[0-9]+'
  # IP addresses with devcontainer port
  '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:9222'
)

# Only check shell scripts and JSON config (not documentation)
# Documentation can contain examples with hostnames
FILES=$(git ls-files --cached 2>/dev/null | grep -E '\.(sh|json)$' | grep -v '\.example' | grep -v 'hardcoded-guard\.yml' | grep -v 'package.*\.json' || true)

if [[ -z "$FILES" ]]; then
  echo "No files to check (not in a git repo or no matching files)"
  exit 0
fi

FOUND=0
for pattern in "${PATTERNS[@]}"; do
  while IFS= read -r file; do
    if [[ -f "$file" ]]; then
      if grep -qE "$pattern" "$file" 2>/dev/null; then
        echo "WARNING: Found hardcoded reference in $file matching: $pattern"
        grep -nE "$pattern" "$file" | head -5 | sed 's/^/  /'
        FOUND=1
      fi
    fi
  done <<< "$FILES"
done

if [[ $FOUND -eq 1 ]]; then
  echo ""
  echo "Hardcoded hostnames or usernames detected!"
  echo "Please use config/env/devcontainer.env for host-specific configuration."
  echo ""
  echo "To fix:"
  echo "  1. Remove hardcoded values from the files above"
  echo "  2. Use environment variables or config file instead"
  echo "  3. See config/env/README.md for setup instructions"
  exit 1
fi

echo "No hardcoded references found."
