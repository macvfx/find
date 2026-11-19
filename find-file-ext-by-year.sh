#!/bin/bash
# Copyright 2025 Mat X
# SPDX-License-Identifier: Apache-2.0
#
# Count files and total size per extension for each year folder, and write a CSV
# in the current directory. Read-only: nothing is changed.

set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: find-file-ext-by-year.sh <directory> <first-year>-<last-year> [extension ...]

For each year in the range, counts files whose path contains a folder named
for that year (for example /Projects/2023/Job/clip.mov), per extension, and
writes a CSV with Year, Extension, File Count and Size (GB).
Default extensions: mov mp4 mxf wav mp3. Case-insensitive.
Sizes are real file sizes in GB (1 GB = 1,000,000,000 bytes, as in Finder).

Example:
  find-file-ext-by-year.sh /Volumes/Projects 2021-2024 mkv
USAGE
}

case "${1:-}" in
    -h|--help) usage; exit 0 ;;
esac
if [ $# -lt 2 ]; then
    usage
    exit 1
fi

search_path="$1"
year_range="$2"
shift 2

if [ ! -d "$search_path" ]; then
    echo "Error: '$search_path' is not a valid directory" >&2
    exit 1
fi
search_path=$(cd "$search_path" && pwd)

if [[ ! "$year_range" =~ ^([0-9]{4})-([0-9]{4})$ ]]; then
    echo "Error: years must look like 2021-2024" >&2
    exit 1
fi
first_year="${BASH_REMATCH[1]}"
last_year="${BASH_REMATCH[2]}"
if [ "$first_year" -gt "$last_year" ]; then
    echo "Error: first year is after last year" >&2
    exit 1
fi

extensions=(mov mp4 mxf wav mp3)
if [ $# -gt 0 ]; then
    extensions+=("$@")
fi

csv_file="./media_files_report_$(date '+%Y%m%d_%H%M%S').csv"
echo "Year,Extension,File Count,Size (GB)" > "$csv_file"

# Drop repeated extensions (case-insensitive) so nothing is counted twice.
unique=()
seen=" "
for ext in "${extensions[@]}"; do
    ext="${ext#.}"
    ext_lc=$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')
    case "$seen" in *" $ext_lc "*) continue ;; esac
    seen="$seen$ext_lc "
    unique+=("$ext")
done

for ((year = first_year; year <= last_year; year++)); do
    for ext in "${unique[@]}"; do
        if [[ ! "$ext" =~ ^[A-Za-z0-9_+-]+$ ]]; then
            echo "Skipping invalid extension: '$ext'" >&2
            continue
        fi

        read -r count bytes < <(
            find "$search_path" -type f -path "*/$year/*" -iname "*.$ext" -exec stat -f %z {} + 2>/dev/null |
                awk '{ n++; s += $1 } END { printf "%d %.0f\n", n, s }'
        )
        gb=$(awk -v b="$bytes" 'BEGIN { printf "%.2f", b / 1000000000 }')
        echo "$year,$ext,$count,$gb" >> "$csv_file"
    done
done

echo "CSV report has been saved to: $csv_file"
