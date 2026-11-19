#!/bin/bash
# Copyright 2025 Mat X
# SPDX-License-Identifier: Apache-2.0
#
# Count files with one extension inside each top-level folder of a path, and
# write the counts to a CSV. Read-only on the scanned folder.

set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: file-type-count2csv-EachSubFolder.sh [--share] <file_extension> <path>

Counts files with the given extension (any case, searched recursively) inside
each folder directly under <path>, and writes one combined CSV: count,folder,baseroot.
The CSV goes in a new folder under $TMPDIR (or /tmp).

  --share   also copy the CSV to /Users/Shared/<volume>_<extension>/

Example:
  file-type-count2csv-EachSubFolder.sh mov /Volumes/Projects/2025
USAGE
}

share=0
args=()
for a in "$@"; do
    case "$a" in
        -h|--help) usage; exit 0 ;;
        --share) share=1 ;;
        *) args+=("$a") ;;
    esac
done
if [ "${#args[@]}" -ne 2 ]; then
    usage
    exit 1
fi

file_ext="${args[0]#.}"
path="${args[1]%/}"

if [[ ! "$file_ext" =~ ^[A-Za-z0-9_+-]+$ ]]; then
    echo "Error: extension may contain only letters, digits, _ + -" >&2
    exit 1
fi
if [ ! -d "$path" ]; then
    echo "Error: '$path' is not a valid directory" >&2
    exit 1
fi

# find -print0 ends each name with a NUL, so names containing newlines count once.
# Names used in file and folder paths: keep only safe characters.
safe() { printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '_'; }
# CSV field: always quoted, quotes doubled, so commas in names are safe.
csv() { printf '"%s"' "${1//\"/\"\"}"; }

volume_name=$(printf '%s' "$path" | awk -F"/Volumes/" 'NF > 1 { print $2 }' | cut -d'/' -f1)
[ -n "$volume_name" ] || volume_name="local"
volume_name=$(safe "$volume_name")
base_root=$(basename "$path")
date_str=$(date +"%Y%m%d")

# mktemp makes an unguessable private folder, unlike a fixed name in /tmp.
csv_dir=$(mktemp -d "${TMPDIR:-/tmp}/filetype_count_${file_ext}_${volume_name}_${date_str}.XXXXXX")
all_csv="$csv_dir/all_folders_combined_${file_ext}_${volume_name}_$(safe "$base_root")_${date_str}.csv"
echo "count,folder,baseroot" > "$all_csv"

for folder in "$path"/*/; do
    [ -d "$folder" ] || continue
    folder_name=$(basename "$folder")
    count=$(find "$folder" -type f -iname "*.$file_ext" -print0 2>/dev/null | tr -cd '\0' | wc -c | tr -d ' ')
    echo "$count,$(csv "$folder_name"),$(csv "$base_root")" >> "$all_csv"
done

echo "CSV saved to: $all_csv"

if [ "$share" -eq 1 ]; then
    shared_dir="/Users/Shared/${volume_name}_${file_ext}"
    mkdir -p "$shared_dir"
    cp "$all_csv" "$shared_dir"
    echo "Copied to: $shared_dir"
fi

if [ -t 1 ] && command -v open >/dev/null 2>&1; then
    open "$csv_dir"
fi
