#!/usr/bin/env bash
set -euo pipefail

# Verify the base devcontainer image is generic: gcc-14 available, no clang toolchains, minimal PATH.
# Usage: scripts/verify_base_image.sh [--image <tag>]

IMAGE_TAG="cpp-cpp-dev-base:local"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --image) IMAGE_TAG="$2"; shift 2;;
    -h|--help) echo "Usage: $0 [--image <tag>]"; exit 0;;
    *) echo "Unknown arg: $1" >&2; exit 1;;
  esac
done

if ! docker image inspect "${IMAGE_TAG}" >/dev/null 2>&1; then
  echo "[verify-base] ERROR: image ${IMAGE_TAG} not found" >&2
  exit 1
fi

CHECK_SCRIPT=$(cat <<'EOF'
set +e
missing=0
check_absent() {
  if command -v "$1" >/dev/null 2>&1; then
    echo "[verify-base] ERROR: unexpected tool present: $1"
    missing=1
  fi
}
check_present() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[verify-base] ERROR: missing tool: $1"
    missing=1
  else
    echo "$1: $($1 --version | head -n1)"
  fi
}
check_present gcc-14
check_absent gcc-15
check_absent clang++
check_absent clang++-21
check_absent clang++-22
exit $missing
EOF
)

printf '%s\n' "${CHECK_SCRIPT}" | docker run --rm "${IMAGE_TAG}" bash -s
