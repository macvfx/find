#!/bin/bash
# Copyright 2025 Mat X
# SPDX-License-Identifier: Apache-2.0
#
# Count files and total size for a list of extensions under a folder, and write
# a timestamped log in the current directory. Read-only: nothing is changed.

set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: find-file-ext-total.sh <directory> [extension ...]

Counts files and adds up their sizes for each extension, matching upper and
lower case (.mov and .MOV). Default extensions: mov mp4 mxf wav mp3.
Sizes are real file sizes in GB (1 GB = 1,000,000,000 bytes, as in Finder).

Example:
  find-file-ext-total.sh /Volumes/Projects mkv avi
USAGE
}

case "${1:-}" in
    -h|--help) usage; exit 0 ;;
esac
if [ $# -lt 1 ]; then
    usage
    exit 1
fi

search_path="$1"
shift

if [ ! -d "$search_path" ]; then
    echo "Error: '$search_path' is not a valid directory" >&2
    exit 1
fi
search_path=$(cd "$search_path" && pwd)

extensions=(mov mp4 mxf wav mp3)
if [ $# -gt 0 ]; then
    extensions+=("$@")
fi

log_file="./media_files_report_$(date '+%Y%m%d_%H%M%S').log"
{
    echo "Media Files Report - $(date)"
    echo "Search directory: $search_path"
    echo "Extensions searched: ${extensions[*]}"
    echo "----------------------------------------"
} > "$log_file"

total_files=0
total_bytes=0

seen=" "
for ext in "${extensions[@]}"; do
    ext="${ext#.}"
    # Skip an extension already searched (for example one repeated in the arguments).
    ext_lc=$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')
    case "$seen" in *" $ext_lc "*) continue ;; esac
    seen="$seen$ext_lc "
    # Extensions go into a find pattern, so allow only plain characters.
    if [[ ! "$ext" =~ ^[A-Za-z0-9_+-]+$ ]]; then
        echo "Skipping invalid extension: '$ext'" | tee -a "$log_file" >&2
        continue
    fi

    # One pass: stat prints one size per file, awk counts and adds them up.
    # Sizes are used, not names, so odd file names cannot break the count.
    # Unreadable folders are skipped quietly.
    read -r count bytes < <(
        find "$search_path" -type f -iname "*.$ext" -exec stat -f %z {} + 2>/dev/null |
            awk '{ n++; s += $1 } END { printf "%d %.0f\n", n, s }'
    )

    if [ "$count" -gt 0 ]; then
        total_files=$((total_files + count))
        total_bytes=$((total_bytes + bytes))
        printf '.%s: %d files, %s GB\n' "$ext" "$count" \
            "$(awk -v b="$bytes" 'BEGIN { printf "%.2f", b / 1000000000 }')" | tee -a "$log_file"
    else
        echo "No .$ext files found" | tee -a "$log_file"
    fi
done

{
    echo "----------------------------------------"
    echo "Total files found: $total_files"
    printf 'Total size: %s GB\n' \
        "$(awk -v b="$total_bytes" 'BEGIN { printf "%.2f", b / 1000000000 }')"
} | tee -a "$log_file"

echo "Log file has been saved to: $log_file"

# Show the log when run from a terminal on a Mac.
if [ -t 1 ] && command -v open >/dev/null 2>&1; then
    open "$log_file"
fi
