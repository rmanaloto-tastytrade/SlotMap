#!/usr/bin/env bash
set -euo pipefail

# Fetch the apt.llvm.org landing page and extract the stable / qualification / development
# branch numbers. Falls back to baked defaults if the scrape fails or regex misses.
# Usage:
#   ./resolve_llvm_branches.sh                # prints "20 21 22"
#   ./resolve_llvm_branches.sh --export       # prints exports: export LLVM_STABLE=20 ...
#   ./resolve_llvm_branches.sh --branch qual  # prints just the qualification number
#   ./resolve_llvm_branches.sh --write file   # writes KEY=VALUE lines to file
#
# This keeps Bake file static; pass values with:
#   eval "$(.devcontainer/scripts/resolve_llvm_branches.sh --export)"
#   docker buildx bake --set CLANG_QUAL=$LLVM_QUAL --set CLANG_DEV=$LLVM_DEV ...

DEFAULT_STABLE=20
DEFAULT_QUAL=21
DEFAULT_DEV=22

branch=""
mode="plain"
outfile=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --export) mode="export"; shift ;;
    --branch) branch="${2:-}"; shift 2 ;;
    --write) outfile="${2:-}"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

fetch_page() {
  # Try gzip first, fall back to plain.
  if content=$(curl -fsSL https://apt.llvm.org/ | gunzip 2>/dev/null); then
    printf '%s' "$content"
    return 0
  fi
  curl -fsSL https://apt.llvm.org/
}

parse_versions() {
  # Looks for: "stable, qualification and development branches (currently 20, 21 and 22)."
  local html="$1"
  local regex='stable, qualification and development branches \\(currently ([0-9]+), ([0-9]+) and ([0-9]+)\\)'
  if [[ $html =~ $regex ]]; then
    echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]} ${BASH_REMATCH[3]}"
  else
    echo "$DEFAULT_STABLE $DEFAULT_QUAL $DEFAULT_DEV"
  fi
}

html=$(fetch_page || true)
read -r LLVM_STABLE LLVM_QUAL LLVM_DEV <<<"$(parse_versions "$html")"

emit_plain() {
  echo "$LLVM_STABLE $LLVM_QUAL $LLVM_DEV"
}

emit_export() {
  cat <<EOF
export LLVM_STABLE=${LLVM_STABLE}
export LLVM_QUAL=${LLVM_QUAL}
export LLVM_DEV=${LLVM_DEV}
EOF
}

emit_branch_only() {
  case "$branch" in
    qual|qualification) echo "$LLVM_QUAL" ;;
    dev|development) echo "$LLVM_DEV" ;;
    stable) echo "$LLVM_STABLE" ;;
    *) echo "Unknown branch '$branch' (use stable|qual|dev)" >&2; exit 1 ;;
  esac
}

emit() {
  if [[ -n "$branch" ]]; then
    emit_branch_only
    return
  fi
  case "$mode" in
    plain) emit_plain ;;
    export) emit_export ;;
    *) emit_plain ;;
  esac
}

output="$(emit)"

if [[ -n "$outfile" ]]; then
  printf '%s\n' "$output" > "$outfile"
else
  printf '%s\n' "$output"
fi
