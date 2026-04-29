#!/bin/bash
set -euo pipefail

USAGE="Usage: $0 [--inplace] <input_dir> <output_dir>"

# Optional flag to write output files to same directory as input
IN_PLACE=0
POSITIONAL=()

for arg in "$@"; do
    case "$arg" in
        --inplace)
            IN_PLACE=1
            ;;
        -h|--help)
            echo "$USAGE" >&2
            echo "Replace legacy NIDM standardized terms with BIDS equivalents in all .jsonld files inside a directory." >&2
            echo "Converted JSONLD files are saved to the output directory." >&2
            exit 0
            ;;
        --*)
            echo "ERROR: Unknown option '$arg'" >&2
            echo "$USAGE" >&2
            exit 1
            ;;
        *)
            POSITIONAL+=("$arg")
            ;;
    esac
done

if [[ ${#POSITIONAL[@]} -ne 2 ]]; then
    echo "ERROR: Expected exactly 2 positional arguments: <input_dir> <output_dir>" >&2
    echo "$USAGE" >&2
    exit 1
fi

INPUT_DIR="${POSITIONAL[0]}"
OUTPUT_DIR="${POSITIONAL[1]}"

if [[ ! -d "$INPUT_DIR" ]]; then
    echo "ERROR: Input directory '$INPUT_DIR' does not exist or is not a directory." >&2
    exit 1
fi

# Normalize input and output directory paths to compare them
input_dir_abs="$(cd "$INPUT_DIR" && pwd -P)"
# NOTE: This will become an empty string (without erroring) if output dir doesn't exist yet
output_dir_abs="$(cd "$OUTPUT_DIR" 2>/dev/null && pwd -P || true)"

same_dir=0
if [[ -n "$output_dir_abs" && "$input_dir_abs" == "$output_dir_abs" ]]; then
    same_dir=1
fi
if [[ "$same_dir" -eq 1 && "$IN_PLACE" -eq 0 ]]; then
    echo "ERROR: Input and output directories resolve to the same path: $input_dir_abs" >&2
    echo "To overwrite files in the input directory, re-run with --inplace." >&2
    exit 2
elif [[ "$same_dir" -eq 0 && "$IN_PLACE" -eq 1 ]]; then
    echo "WARNING: --inplace will be ignored since input and output directories are different." >&2
fi

# Build sed expression from hardcoded mapping
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

    if [[ "$same_dir" -eq 1 ]]; then
        # If input and output directories are the same, write to a temp file first
        tmp="$(mktemp "${input_file}.tmp.XXXXXX")"
        sed -E "$SED_EXPR" "$input_file" > "$tmp"
        if cmp -s "$input_file" "$tmp"; then
            echo "No changes needed to '$input_file'"
            rm -f "$tmp"
        else
            mv -f "$tmp" "$output_file"
            echo "Converted '$input_file' in-place"
        fi
    else
        sed -E "$SED_EXPR" "$input_file" > "$output_file"
        # Check if output is identical to input
        if cmp -s "$input_file" "$output_file"; then
            echo "Converted '$input_file' -> '$output_file' (no changes needed)"
        else
            echo "Converted '$input_file' -> '$output_file'"
        fi
    fi
done
