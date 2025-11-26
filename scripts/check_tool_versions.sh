#!/usr/bin/env bash
set -euo pipefail

# Check latest versions of tools used in the devcontainer
# Run this periodically to detect when updates are available
#
# Usage: scripts/check_tool_versions.sh [--json]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BAKE_FILE="$REPO_ROOT/.devcontainer/docker-bake.hcl"

JSON_OUTPUT=0
if [[ "${1:-}" == "--json" ]]; then
  JSON_OUTPUT=1
fi

# Extract current versions from docker-bake.hcl
get_current_version() {
  local var_name=$1
  grep -E "^[[:space:]]*${var_name}[[:space:]]*=" "$BAKE_FILE" | head -1 | sed -E 's/.*=[[:space:]]*"([^"]+)".*/\1/'
}

# Get latest GitHub release tag
get_github_latest() {
  local repo=$1
  local tag
  tag=$(curl -sfL "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null | grep '"tag_name"' | head -1 | sed -E 's/.*"tag_name":[[:space:]]*"([^"]+)".*/\1/' || echo "error")
  # Strip leading 'v' if present for comparison
  echo "${tag#v}"
}

# Get latest GitHub tag (for repos that don't use releases)
get_github_tag() {
  local repo=$1
  local prefix=${2:-}
  local tag
  tag=$(curl -sfL "https://api.github.com/repos/${repo}/tags" 2>/dev/null | grep '"name"' | head -1 | sed -E 's/.*"name":[[:space:]]*"([^"]+)".*/\1/' || echo "error")
  echo "${tag#$prefix}"
}

# Check Node.js latest version
get_nodejs_latest() {
  curl -sfL "https://nodejs.org/dist/index.json" 2>/dev/null | grep -oE '"version":"v[0-9]+\.[0-9]+\.[0-9]+"' | head -1 | sed -E 's/"version":"v([^"]+)"/\1/' || echo "error"
}

# Check LLVM latest version
get_llvm_latest() {
  # LLVM apt repo typically lags behind source releases
  # Check apt.llvm.org for available versions
  curl -sfL "https://apt.llvm.org/" 2>/dev/null | grep -oE 'llvm-[0-9]+' | sort -t- -k2 -n | tail -1 | sed 's/llvm-//' || echo "error"
}

# Compare versions (returns "update" if latest > current, "current" if equal, "ahead" if current > latest)
compare_versions() {
  local current=$1
  local latest=$2

  if [[ "$current" == "$latest" ]]; then
    echo "current"
  elif [[ "$latest" == "error" ]] || [[ -z "$latest" ]]; then
    echo "unknown"
  else
    # Simple version comparison (works for semver)
    if printf '%s\n%s\n' "$current" "$latest" | sort -V | head -1 | grep -qx "$current"; then
      if [[ "$current" != "$latest" ]]; then
        echo "update"
      else
        echo "current"
      fi
    else
      echo "ahead"
    fi
  fi
}

# Print status with color
print_status() {
  local tool=$1
  local current=$2
  local latest=$3
  local status=$4

  if [[ $JSON_OUTPUT -eq 1 ]]; then
    return
  fi

  local color=""
  local reset="\033[0m"
  case "$status" in
    update)  color="\033[1;33m" ;;  # Yellow
    current) color="\033[1;32m" ;;  # Green
    ahead)   color="\033[1;36m" ;;  # Cyan
    unknown) color="\033[1;31m" ;;  # Red
  esac

  printf "%-20s %-12s %-12s ${color}%-10s${reset}\n" "$tool" "$current" "$latest" "$status"
}

# Main version checks
declare -A VERSIONS

echo ""
if [[ $JSON_OUTPUT -eq 0 ]]; then
  echo "DevContainer Tool Version Check"
  echo "================================"
  echo "Date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  echo ""
  printf "%-20s %-12s %-12s %-10s\n" "TOOL" "CURRENT" "LATEST" "STATUS"
  printf "%-20s %-12s %-12s %-10s\n" "----" "-------" "------" "------"
fi

# LLVM
CURRENT=$(get_current_version "LLVM_VERSION")
LATEST=$(get_llvm_latest)
STATUS=$(compare_versions "$CURRENT" "$LATEST")
print_status "LLVM" "$CURRENT" "$LATEST" "$STATUS"
VERSIONS["LLVM"]="$CURRENT|$LATEST|$STATUS"

# Ninja
CURRENT=$(get_current_version "NINJA_VERSION")
LATEST=$(get_github_latest "ninja-build/ninja")
STATUS=$(compare_versions "$CURRENT" "$LATEST")
print_status "Ninja" "$CURRENT" "$LATEST" "$STATUS"
VERSIONS["Ninja"]="$CURRENT|$LATEST|$STATUS"

# mold
CURRENT=$(get_current_version "MOLD_VERSION")
LATEST=$(get_github_latest "rui314/mold")
STATUS=$(compare_versions "$CURRENT" "$LATEST")
print_status "mold" "$CURRENT" "$LATEST" "$STATUS"
VERSIONS["mold"]="$CURRENT|$LATEST|$STATUS"

# ccache
CURRENT=$(get_current_version "CCACHE_VERSION")
LATEST=$(get_github_latest "ccache/ccache")
STATUS=$(compare_versions "$CURRENT" "$LATEST")
print_status "ccache" "$CURRENT" "$LATEST" "$STATUS"
VERSIONS["ccache"]="$CURRENT|$LATEST|$STATUS"

# sccache
CURRENT=$(get_current_version "SCCACHE_VERSION")
LATEST=$(get_github_latest "mozilla/sccache")
STATUS=$(compare_versions "$CURRENT" "$LATEST")
print_status "sccache" "$CURRENT" "$LATEST" "$STATUS"
VERSIONS["sccache"]="$CURRENT|$LATEST|$STATUS"

# GitHub CLI
CURRENT=$(get_current_version "GH_CLI_VERSION")
LATEST=$(get_github_latest "cli/cli")
STATUS=$(compare_versions "$CURRENT" "$LATEST")
print_status "gh-cli" "$CURRENT" "$LATEST" "$STATUS"
VERSIONS["gh-cli"]="$CURRENT|$LATEST|$STATUS"

# ripgrep
CURRENT=$(get_current_version "RIPGREP_VERSION")
LATEST=$(get_github_latest "BurntSushi/ripgrep")
STATUS=$(compare_versions "$CURRENT" "$LATEST")
print_status "ripgrep" "$CURRENT" "$LATEST" "$STATUS"
VERSIONS["ripgrep"]="$CURRENT|$LATEST|$STATUS"

# MrDocs
CURRENT=$(get_current_version "MRDOCS_VERSION" | sed 's/^v//')
LATEST=$(get_github_latest "cppalliance/mrdocs")
STATUS=$(compare_versions "$CURRENT" "$LATEST")
print_status "MrDocs" "$CURRENT" "$LATEST" "$STATUS"
VERSIONS["MrDocs"]="$CURRENT|$LATEST|$STATUS"

# Node.js
CURRENT=$(get_current_version "NODE_VERSION")
LATEST=$(get_nodejs_latest)
STATUS=$(compare_versions "$CURRENT" "$LATEST")
print_status "Node.js" "$CURRENT" "$LATEST" "$STATUS"
VERSIONS["Node.js"]="$CURRENT|$LATEST|$STATUS"

# jq
CURRENT=$(get_current_version "JQ_VERSION")
LATEST=$(get_github_latest "jqlang/jq" | sed 's/^jq-//')
STATUS=$(compare_versions "$CURRENT" "$LATEST")
print_status "jq" "$CURRENT" "$LATEST" "$STATUS"
VERSIONS["jq"]="$CURRENT|$LATEST|$STATUS"

# binutils-gdb (uses tags, not releases) - filter for binutils-* tags only
CURRENT=$(get_current_version "BINUTILS_GDB_TAG" | sed 's/binutils-//' | tr '_' '.')
# Get latest binutils tag (filter to only binutils-X_XX tags)
LATEST=$(curl -sfL "https://api.github.com/repos/bminor/binutils-gdb/tags?per_page=100" 2>/dev/null | grep -oE '"name":[[:space:]]*"binutils-[0-9_]+"' | head -1 | sed -E 's/.*"binutils-([^"]+)".*/\1/' | tr '_' '.' || echo "error")
STATUS=$(compare_versions "$CURRENT" "$LATEST")
print_status "binutils-gdb" "$CURRENT" "$LATEST" "$STATUS"
VERSIONS["binutils-gdb"]="$CURRENT|$LATEST|$STATUS"

# JSON output
if [[ $JSON_OUTPUT -eq 1 ]]; then
  echo "{"
  printf '  "timestamp": "%s",\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo '  "tools": {'
  first=true
  for tool in "${!VERSIONS[@]}"; do
    IFS='|' read -r current latest status <<< "${VERSIONS[$tool]}"
    if [[ $first == true ]]; then
      first=false
    else
      echo ","
    fi
    printf '    "%s": {"current": "%s", "latest": "%s", "status": "%s"}' "$tool" "$current" "$latest" "$status"
  done
  echo ""
  echo "  }"
  echo "}"
  exit 0
fi

# Summary
echo ""
UPDATE_COUNT=0
for tool in "${!VERSIONS[@]}"; do
  IFS='|' read -r current latest status <<< "${VERSIONS[$tool]}"
  if [[ "$status" == "update" ]]; then
    ((UPDATE_COUNT++))
  fi
done

if [[ $UPDATE_COUNT -gt 0 ]]; then
  echo "Updates available: $UPDATE_COUNT tool(s)"
  echo ""
  echo "To update, edit .devcontainer/docker-bake.hcl and rebuild:"
  echo "  docker buildx bake -f .devcontainer/docker-bake.hcl"
else
  echo "All tools are up to date."
fi
