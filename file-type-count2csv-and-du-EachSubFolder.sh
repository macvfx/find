#!/bin/bash
# Copyright 2025 Mat X
# SPDX-License-Identifier: Apache-2.0
#
# For every folder two levels below a path (path/year/project), count files with
# one extension and measure the folder's total size, then write a CSV.
# Read-only on the scanned folder.

set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: file-type-count2csv-and-du-EachSubFolder.sh [--share] <file_extension> <path>

Looks at each folder two levels below <path> (for example path/2025/ProjectName).
For each one, counts files with the extension directly inside it (any case, not
in deeper folders) and reports the folder's whole size in GB (1 GB = 1,000,000,000
bytes). Writes one combined CSV: project,path,filetype_count,du_size_GB.
The CSV goes in a new folder under $TMPDIR (or /tmp).

  --share   also copy the CSV to /Users/Shared/<volume>_<extension>/

Example:
  file-type-count2csv-and-du-EachSubFolder.sh r3d /Volumes/Projects
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

safe() { printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '_'; }
csv() { printf '"%s"' "${1//\"/\"\"}"; }

volume_name=$(printf '%s' "$path" | awk -F"/Volumes/" 'NF > 1 { print $2 }' | cut -d'/' -f1)
[ -n "$volume_name" ] || volume_name="local"
volume_name=$(safe "$volume_name")
base_root=$(basename "$path")
date_str=$(date +"%Y%m%d")

csv_dir=$(mktemp -d "${TMPDIR:-/tmp}/du_filetype_count_${file_ext}_${volume_name}_${date_str}.XXXXXX")
all_csv="$csv_dir/all_folders_combined_${file_ext}_${volume_name}_$(safe "$base_root")_${date_str}.csv"
echo "project,path,filetype_count,du_size_GB" > "$all_csv"

for folder in "$path"/*/; do
    [ -d "$folder" ] || continue
    for subfolder in "$folder"*/; do
        [ -d "$subfolder" ] || continue
        subfolder_name=$(basename "$subfolder")
        count=$(find "$subfolder" -maxdepth 1 -type f -iname "*.$file_ext" -print0 2>/dev/null | tr -cd '\0' | wc -c | tr -d ' ')
        # du -k gives exact kilobytes; du -g would round every folder up to a whole GB.
        kb=$(du -sk "$subfolder" 2>/dev/null | awk '{ print $1 }')
        gb=$(awk -v k="${kb:-0}" 'BEGIN { printf "%.2f", k * 1024 / 1000000000 }')
        echo "$(csv "$subfolder_name"),$(csv "${subfolder%/}"),$count,$gb" >> "$all_csv"
    done
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
