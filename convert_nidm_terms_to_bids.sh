#!/bin/bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
    echo "Replace legacy NIDM standardized terms with BIDS equivalents in all .jsonld files inside a directory." >&2
    echo "Converted JSONLD files are saved to the output directory." >&2
    echo "Usage: $0 <input_dir> <output_dir>" >&2
    exit 1
fi

INPUT_DIR="$1"
OUTPUT_DIR="$2"

# We're building ${SED_EXPR} incrementally for each mapping for readability
SED_EXPR=""
add() { SED_EXPR="${SED_EXPR}s|${1}|${2}|g;"; }
 
add "nidm"                          "bids"
add "http://purl.org/nidash/nidm#"  "https://bids.neuroimaging.io/terms/"
add "T1Weighted"                    "T1w"
add "T2Weighted"                    "T2w"
add "DiffusionWeighted"             "dwi"
add "FlowWeighted"                  "bold"
add "ArterialSpinLabeling"          "asl"
add "Electroencephalography"        "eeg"
add "Magnetoencephalography"        "meg"
add "PositronEmissionTomography"    "pet"

# Ensure unmatched globs expand to an empty array
shopt -s nullglob
input_files=("$INPUT_DIR"/*.jsonld)
 
# Check if input directory contains any JSONLDs
if [[ ${#input_files[@]} -eq 0 ]]; then
    echo "No .jsonld files found in '$INPUT_DIR'." >&2
    exit 1
fi

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

for input_file in "${input_files[@]}"; do
    filename=$(basename "$input_file")
    output_file="${OUTPUT_DIR}/${filename}"
    sed -E "$SED_EXPR" "$input_file" > "$output_file"
    # Check if output is identical to input
    if cmp -s "$input_file" "$output_file"; then
        echo "Converted '$input_file' -> '$output_file' (no changes needed)"
    else
        echo "Converted '$input_file' -> '$output_file'"
    fi
done
