#!/usr/bin/env bash
set -euo pipefail

function show_help {
    cat <<'USAGE'
Usage: generate_docs.sh --source <path> --build <path> --mrdocs <bin> --doxygen <bin>
USAGE
}

SOURCE_DIR=""
BUILD_DIR=""
MRDOCS_BIN=""
DOXYGEN_BIN=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --source)
            SOURCE_DIR="$2"; shift 2;;
        --build)
            BUILD_DIR="$2"; shift 2;;
        --mrdocs)
            MRDOCS_BIN="$2"; shift 2;;
        --doxygen)
            DOXYGEN_BIN="$2"; shift 2;;
        -h|--help)
            show_help; exit 0;;
        *)
            echo "Unknown argument: $1" >&2; show_help; exit 1;;
    esac
done

if [[ -z "$SOURCE_DIR" || -z "$BUILD_DIR" || -z "$MRDOCS_BIN" || -z "$DOXYGEN_BIN" ]]; then
    echo "Missing required arguments" >&2
    show_help
    exit 1
fi

mkdir -p "$BUILD_DIR"

MRDOCS_OUT="$BUILD_DIR/mrdocs"
DOXYGEN_OUT="$BUILD_DIR/doxygen"

cmake -E make_directory "$MRDOCS_OUT" "$DOXYGEN_OUT"

"$MRDOCS_BIN" \
    --source-root "$SOURCE_DIR" \
    --config "$SOURCE_DIR/docs/mrdocs.yml" \
    --output "$MRDOCS_OUT"

cmake -E env \
    SLOTMAP_SOURCE_ROOT="$SOURCE_DIR" \
    SLOTMAP_DOXYGEN_OUTPUT="$DOXYGEN_OUT" \
    "$DOXYGEN_BIN" "$SOURCE_DIR/docs/Doxyfile"
