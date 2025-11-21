#!/usr/bin/env bash
set -euo pipefail

# Validate docker-bake.hcl syntax/targets without building.
# Usage: scripts/check_docker_bake.sh [path-to-repo-root]

REPO_ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
BAKE_FILE="$REPO_ROOT/.devcontainer/docker-bake.hcl"

if [[ ! -f "$BAKE_FILE" ]]; then
  echo "ERROR: Bake file not found at $BAKE_FILE" >&2
  exit 1
fi

echo "[check] Validating bake file: $BAKE_FILE"
docker buildx bake -f "$BAKE_FILE" --print devcontainer > /dev/null
echo "[check] Bake file OK."
