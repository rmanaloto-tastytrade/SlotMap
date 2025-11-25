#!/usr/bin/env bash
set -euo pipefail

# Generate SVG/PNG from Mermaid diagrams
# Requires: mmdc (mermaid-cli) - installed in devcontainer

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DIAGRAMS_DIR="$REPO_ROOT/docs/Diagrams"
OUTPUT_DIR="$DIAGRAMS_DIR/rendered"

usage() {
    cat <<'EOF'
Usage: scripts/generate_diagrams.sh [options]

Generate SVG and PNG from Mermaid (.mmd) diagram files.

Options:
    --format <svg|png|both>   Output format (default: both)
    --input <path>            Single .mmd file to render
    --output <dir>            Output directory (default: docs/Diagrams/rendered)
    --theme <default|dark>    Mermaid theme (default: default)
    -h, --help                Show this help

Examples:
    # Render all diagrams
    ./scripts/generate_diagrams.sh

    # Render single file as PNG
    ./scripts/generate_diagrams.sh --input docs/Diagrams/docker-bake-stages.mmd --format png

    # Render with dark theme
    ./scripts/generate_diagrams.sh --theme dark
EOF
}

FORMAT="both"
INPUT_FILE=""
THEME="default"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --format)
            FORMAT="$2"; shift 2 ;;
        --input)
            INPUT_FILE="$2"; shift 2 ;;
        --output)
            OUTPUT_DIR="$2"; shift 2 ;;
        --theme)
            THEME="$2"; shift 2 ;;
        -h|--help)
            usage; exit 0 ;;
        *)
            echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

# Check for mmdc
if ! command -v mmdc &>/dev/null; then
    echo "Error: mmdc (mermaid-cli) not found."
    echo "Install with: npm install -g @mermaid-js/mermaid-cli"
    echo "Or run inside the devcontainer where it's pre-installed."
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

render_diagram() {
    local input="$1"
    local basename
    basename="$(basename "$input" .mmd)"

    echo "Rendering: $input"

    if [[ "$FORMAT" == "svg" ]] || [[ "$FORMAT" == "both" ]]; then
        mmdc -i "$input" -o "$OUTPUT_DIR/${basename}.svg" -t "$THEME" -b transparent
        echo "  -> $OUTPUT_DIR/${basename}.svg"
    fi

    if [[ "$FORMAT" == "png" ]] || [[ "$FORMAT" == "both" ]]; then
        mmdc -i "$input" -o "$OUTPUT_DIR/${basename}.png" -t "$THEME" -b white -s 2
        echo "  -> $OUTPUT_DIR/${basename}.png"
    fi
}

if [[ -n "$INPUT_FILE" ]]; then
    if [[ ! -f "$INPUT_FILE" ]]; then
        echo "Error: File not found: $INPUT_FILE" >&2
        exit 1
    fi
    render_diagram "$INPUT_FILE"
else
    # Find all .mmd files
    shopt -s nullglob
    mmd_files=("$DIAGRAMS_DIR"/*.mmd)

    if [[ ${#mmd_files[@]} -eq 0 ]]; then
        echo "No .mmd files found in $DIAGRAMS_DIR"
        exit 0
    fi

    echo "Found ${#mmd_files[@]} diagram(s) to render"
    echo ""

    for mmd in "${mmd_files[@]}"; do
        render_diagram "$mmd"
    done
fi

echo ""
echo "Done! Rendered diagrams in: $OUTPUT_DIR"
