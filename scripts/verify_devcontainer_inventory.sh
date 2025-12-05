#!/usr/bin/env bash
set -euo pipefail

# Enforce a clean set of cpp-devcontainer images and no dangling layers.
# - Builds expected image list from config/env/devcontainer*.env (DEVCONTAINER_IMAGE entries) plus EXTRA_EXPECTED_IMAGES.
# - Fails if dangling images exist.
# - Fails if actual cpp-devcontainer:* images are not in the expected set or if expected images are missing.
#
# Usage:
#   scripts/verify_devcontainer_inventory.sh
#   EXTRA_EXPECTED_IMAGES="cpp-devcontainer:local" scripts/verify_devcontainer_inventory.sh

REPO_ROOT="$(git rev-parse --show-toplevel)"

expected=()
while IFS= read -r line; do
  img="${line#DEVCONTAINER_IMAGE=}"
  if [[ "$img" == cpp-devcontainer:* ]]; then
    expected+=("$img")
  fi
done < <(grep -h '^DEVCONTAINER_IMAGE=' "$REPO_ROOT"/config/env/devcontainer*.env 2>/dev/null | sort -u)

if [[ -n "${EXTRA_EXPECTED_IMAGES:-}" ]]; then
  for img in ${EXTRA_EXPECTED_IMAGES}; do
    expected+=("$img")
  done
fi

if [[ ${#expected[@]} -eq 0 ]]; then
  echo "[inventory] WARNING: no cpp-devcontainer images listed in config/env; skipping inventory check."
  exit 0
fi

mapfile -t actual < <(docker images --format '{{.Repository}}:{{.Tag}}' | grep '^cpp-devcontainer:' || true)

dangling="$(docker images -f dangling=true -q)"
if [[ -n "$dangling" ]]; then
  echo "[inventory] ERROR: dangling images present. Run: docker rmi \$(docker images -f dangling=true -q)" >&2
  exit 1
fi

missing=0
for exp in "${expected[@]}"; do
  if ! printf '%s\n' "${actual[@]}" | grep -qx "$exp"; then
    echo "[inventory] ERROR: expected image missing: $exp"
    missing=1
  fi
done

extra=0
for act in "${actual[@]}"; do
  if ! printf '%s\n' "${expected[@]}" | grep -qx "$act"; then
    echo "[inventory] ERROR: unexpected cpp-devcontainer image present: $act"
    extra=1
  fi
done

if [[ $missing -ne 0 || $extra -ne 0 ]]; then
  exit 1
fi

echo "[inventory] cpp-devcontainer images match expected set."
