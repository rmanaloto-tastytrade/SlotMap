#!/usr/bin/env bash
set -euo pipefail

# Clean buildx caches on a given Docker context/builder without nuking images.
# By default targets the remote context and builder used for devcontainer builds.
#
# Usage:
#   scripts/clean_buildx_cache.sh [--context <name>] [--builder <name>] [--all]
#     --context : Docker context (default: ${DOCKER_CONTEXT:-ssh-<host>})
#     --builder : Buildx builder name (default: devcontainer-remote)
#     --all     : Also prune all cache (including dangling); otherwise prune exec caches only.
#
# Note: run from the repo root. Requires docker/buildx installed on the host invoking this script.

CONTEXT="${DOCKER_CONTEXT:-}"
BUILDER="${DEVCONTAINER_BUILDER_NAME:-devcontainer-remote}"
PRUNE_ALL=0

usage() {
  cat <<EOF
Usage: scripts/clean_buildx_cache.sh [options]
  --context <name>   Docker context to target (default: ${CONTEXT})
  --builder <name>   Buildx builder name (default: ${BUILDER})
  --all              Prune all caches (not just exec/cachemount)
  -h, --help         Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --context) CONTEXT="$2"; shift 2 ;;
    --builder) BUILDER="$2"; shift 2 ;;
    --all) PRUNE_ALL=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

echo "[cache] Using context=${CONTEXT}, builder=${BUILDER}"

if ! docker --context "$CONTEXT" buildx inspect "$BUILDER" >/dev/null 2>&1; then
  echo "[cache] Builder '$BUILDER' not found on context '$CONTEXT'." >&2
  exit 1
fi

echo "[cache] Current cache usage:"
docker --context "$CONTEXT" buildx du --builder "$BUILDER" || true

if [[ "$PRUNE_ALL" == "1" ]]; then
  echo "[cache] Pruning all buildx caches..."
  docker --context "$CONTEXT" buildx prune --builder "$BUILDER" -f
else
  echo "[cache] Pruning exec/cachemount caches only..."
  docker --context "$CONTEXT" buildx prune --builder "$BUILDER" -f --filter type=exec.cachemount
fi

echo "[cache] Cache usage after prune:"
docker --context "$CONTEXT" buildx du --builder "$BUILDER" || true
