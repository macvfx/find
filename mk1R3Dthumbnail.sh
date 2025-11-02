#!/bin/bash
# mk1R3Dthumbnails.sh
#
# README / Usage
#
# Purpose:
#   Walk a directory tree, find .R3D files and generate a single-frame JPEG
#   thumbnail per clip using REDline (REDCINE-X CLI). Thumbnails are placed
#   in <directory>/Thumbnails/.
#
# Flags:
#   --dry-run   : do not invoke REDline; print the REDline command that would run
#   --verbose   : stream REDline output to the terminal in addition to logging
#
# Logging:
#   Each run writes REDline stdout/stderr into Thumbnails/logs/mk1R3DthumbnailsVS_YYYYMMDD_HHMMSS.log
#   The script keeps only the 10 most recent logs.
#
# Behavior notes:
#   - The script prefers exact output filenames but detects when REDline appends
#     numeric/frame suffixes (e.g., out.jpg.000001.jpg). It chooses the best
#     candidate (exact > highest numeric suffix > latest-modified) and renames
#     it to the canonical filename. Auxiliary/suffixed files are removed.
#   - Run the script with `bash /Library/Scripts/mk1R3DthumbnailsVS.sh --dry-run <dir>`
#     if you want to preview commands.
#
# Exit codes:
#   0 : success (created >=1 thumbnails)
#   1 : usage / missing directory
#   2 : REDline not in PATH
#   3 : completed but no thumbnails created
#
# Changes made:
# - Added a usage check and explicit directory-exists validation to fail fast if arguments are missing or wrong.
# - Create a "Thumbnails" directory (if missing) to collect all generated thumbnail files.
# - Use find ... -print0 combined with while IFS= read -r -d '' to safely handle filenames with spaces/newlines.
# - Limit processing to files matching "*_001.r3d" or "*_001.R3D" located inside ".RDC" folders.
# - Use basename and parameter expansion (${var%.*}) to derive a thumbnail base name from each source file.
# - Invoke REDline to generate thumbnails and write an informative echo for each created file.
# - Final message echoes successful creation and the Thumbnails directory path.
#
# Robust shell settings
set -euo pipefail
IFS=$'\n\t'

# Fail fast if REDline is not available
if ! command -v REDline >/dev/null 2>&1; then
    echo "ERROR: REDline not found in PATH" >&2
    exit 2
fi

# Notes:
# Use "mkdir -p" when creating the Thumbnails directory (simpler and idempotent).
mkdir_p() { mkdir -p -- "$1"; }
# - Remove duplicated REDline invocation and ensure the generated thumbnail has the intended extension (e.g. .jpg).
# - Ensure the "done" for the while-loop and the final "Thumbnails created..." message are placed outside the loop.

# Default flags
DRY_RUN=0
VERBOSE=0

# Simple flag parsing for --dry-run and --verbose (and directory argument)
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)
            DRY_RUN=1; shift ;;
        --verbose)
            VERBOSE=1; shift ;;
        --)
            shift; break ;;
        -*)
            echo "Unknown option: $1" >&2; exit 1 ;;
        *)
            # first non-option is the directory
            directory="$1"; shift; break ;;
    esac
done

# If directory wasn't provided yet, try to take the next positional arg
if [ -z "${directory:-}" ]; then
    if [ $# -gt 0 ]; then
        directory="$1"
    fi
fi

# Check if at least one argument (directory) is provided
if [ -z "${directory:-}" ]; then
    echo "Usage: $0 [--dry-run] [--verbose] <directory_path>"
    exit 1
fi

# Check if directory exists
if [ ! -d "$directory" ]; then
    echo "Directory '$directory' not found."
    exit 1
fi

# Create Thumbnails directory if it doesn't exist
thumbnails_dir="$directory/Thumbnails"
if [ ! -d "$thumbnails_dir" ]; then
    mkdir_p "$thumbnails_dir"
fi

# Prepare rotating log directory inside Thumbnails
logs_dir="$thumbnails_dir/logs"
mkdir_p "$logs_dir"
# Create timestamp early so filenames can use it
timestamp=$(date +%Y%m%d_%H%M%S)
# Directory to track processed RDC folders so we only handle the first R3D per RDC
processed_dir="$logs_dir/processed_rdc"
mkdir_p "$processed_dir"
processed_list="$logs_dir/processed_rdc_list_$timestamp.txt"
>"$processed_list"
# Create a per-run log name (timestamped). Keep last 10 logs.
run_log="$logs_dir/mk1R3DthumbnailsVS_$timestamp.log"

# Rotate logs: keep only the 10 most recent logs
if command -v ls >/dev/null 2>&1; then
    ls -1t "$logs_dir"/mk1R3DthumbnailsVS_*.log 2>/dev/null | sed -n '11,$p' | xargs -r rm -- 2>/dev/null || true
fi

# Find all *_001.r3d or *_001.R3D files within .RDC folders and process them
# Find R3D files (case-insensitive) anywhere under the provided directory.
# Use process-substitution instead of piping into while so we don't run the loop in a subshell
# which would prevent updating a counter in the parent shell.
count=0
while IFS= read -r -d '' r3d_file; do
    r3d_filename="$(basename "$r3d_file")"
    thumbnail_filename="${r3d_filename%.*}"
    thumbnail_path="$thumbnails_dir/${thumbnail_filename}.jpg"

    # Determine the nearest parent folder whose name ends with .RDC (if any)
    rdc_root=""
    cur_dir=$(dirname "$r3d_file")
    while true; do
        base=$(basename "$cur_dir")
        # case-insensitive match for .RDC
        shopt -s nocasematch
        if [[ "$base" == *.rdc ]]; then
            rdc_root="$cur_dir"
            shopt -u nocasematch
            break
        fi
        shopt -u nocasematch
        parent=$(dirname "$cur_dir")
        if [ "$parent" = "$cur_dir" ] || [ -z "$parent" ]; then
            break
        fi
        cur_dir="$parent"
    done

    # If this R3D lives in an .RDC folder, skip it if that RDC has already been recorded this run
    if [ -n "$rdc_root" ]; then
        if grep -Fxq -- "$rdc_root" "$processed_list" 2>/dev/null; then
            [ "$VERBOSE" -eq 1 ] && echo "Skipping $r3d_file: RDC already processed this run ($rdc_root)"
            continue
        else
            # record it now so subsequent files in this RDC are skipped
            echo "$rdc_root" >>"$processed_list"
            [ "$VERBOSE" -eq 1 ] && echo "Recording RDC for processing: $rdc_root"
        fi
    fi

    # Build REDline command
    cmd=(REDline --i "$r3d_file" --o "$thumbnail_path" --pad 0 --format 3 --frameCount 1)

    # Echo the command when verbose or dry-run
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "DRY-RUN: would run: ${cmd[*]}"
        continue
    fi

    if [ "$VERBOSE" -eq 1 ]; then
        echo "Running: ${cmd[*]}"
        # Run REDline and tee output to run_log (append)
        REDline --i "$r3d_file" --o "$thumbnail_path" --pad 0 --format 3 --frameCount 1 2>&1 | tee -a "$run_log"
        rc=${PIPESTATUS[0]:-0}
    else
        # Redirect REDline stdout/stderr to per-run log
        REDline --i "$r3d_file" --o "$thumbnail_path" --pad 0 --format 3 --frameCount 1 >>"$run_log" 2>&1
        rc=$?
    fi

    if [ $rc -eq 0 ]; then
        # REDline sometimes appends a numeric/frame suffix to the output filename
        # e.g. /path/out.jpg -> /path/out.jpg.000001.jpg. Detect matches and pick the best candidate.
        shopt -s nullglob
        matches=("${thumbnail_path}"*)
        if [ ${#matches[@]} -gt 0 ]; then
            chosen=""
            # If exact match exists, prefer it
            for m in "${matches[@]}"; do
                if [ "$m" = "$thumbnail_path" ]; then
                    chosen="$m"
                    break
                fi
            done

            if [ -z "$chosen" ]; then
                # Try to find files with an appended numeric suffix like .000001.jpg
                # Choose the file with the highest numeric suffix if present, else the most recently modified file.
                highest_num=-1
                highest_file=""
                latest_mtime=0
                latest_file=""
                for m in "${matches[@]}"; do
                    # Extract trailing numeric group before the final extension, e.g. out.jpg.000123.jpg
                    # Pattern: *.jpg.<number>.jpg or *.jpg.<number>
                    if [[ "$m" =~ \.([0-9]{1,})\.[^.]+$ ]]; then
                        num=${BASH_REMATCH[1]}
                        if [ "$num" -gt "$highest_num" ]; then
                            highest_num=$num
                            highest_file="$m"
                        fi
                    fi
                    # track latest modified as fallback
                    mtime=$(stat -f %m -- "$m" 2>/dev/null || stat -c %Y -- "$m" 2>/dev/null || echo 0)
                    if [ "$mtime" -gt "$latest_mtime" ]; then
                        latest_mtime=$mtime
                        latest_file="$m"
                    fi
                done

                if [ -n "$highest_file" ]; then
                    chosen="$highest_file"
                else
                    chosen="$latest_file"
                fi
            fi

                if [ -n "$chosen" ]; then
                    if [ "$chosen" != "$thumbnail_path" ]; then
                        if mv -- "$chosen" "$thumbnail_path"; then
                            echo "Created thumbnail: \"$thumbnail_path\"" >>"$run_log"
                            [ "$VERBOSE" -eq 1 ] && echo "Created thumbnail: \"$thumbnail_path\""
                            count=$((count + 1))
                        else
                            echo "Failed to rename generated file \"${chosen}\" to \"$thumbnail_path\"" >&2
                            echo "Failed to rename generated file \"${chosen}\" to \"$thumbnail_path\"" >>"$run_log"
                        fi
                    else
                        echo "Created thumbnail: \"$thumbnail_path\"" >>"$run_log"
                        [ "$VERBOSE" -eq 1 ] && echo "Created thumbnail: \"$thumbnail_path\""
                        count=$((count + 1))
                    fi

                    # Remove any auxiliary/suffixed files produced by REDline so only the canonical file remains
                    for m in "${matches[@]}"; do
                        if [ "$m" != "$thumbnail_path" ]; then
                            if rm -f -- "$m" 2>/dev/null; then
                                echo "Removed auxiliary file: $m" >>"$run_log"
                                [ "$VERBOSE" -eq 1 ] && echo "Removed auxiliary file: $m"
                            fi
                        fi
                    done
                else
                    echo "Warning: REDline reported success but no output file was found for: \"$r3d_file\"" >&2
                    echo "Warning: no matched output for $r3d_file" >>"$run_log"
                fi
        else
            echo "Warning: REDline reported success but no output file was found for: \"$r3d_file\"" >&2
            echo "Warning: no matched output for $r3d_file" >>"$run_log"
        fi
        shopt -u nullglob
    else
        echo "Failed to create thumbnail for: \"$r3d_file\"" >&2
        echo "REDline failed for $r3d_file (rc=$rc)" >>"$run_log"
    fi
done < <(find "$directory" -type f -iname "*.r3d" -print0)

# After processing all files, write persistent marker files for each processed RDC (unless dry-run)
if [ "$DRY_RUN" -eq 0 ]; then
    while IFS= read -r rdc_line; do
        [ -z "$rdc_line" ] && continue
        processed_id=$(printf '%s' "$rdc_line" | sed 's/[^A-Za-z0-9._-]/_/g')
        touch "$processed_dir/processed_${processed_id}.marker" 2>/dev/null || true
    done <"$processed_list"
else
    if [ -s "$processed_list" ]; then
        echo "DRY-RUN: would create markers for RDCs listed in $processed_list" >&2
    fi
fi

if [ "$count" -eq 0 ]; then
    echo "No R3D files were found or no thumbnails were created in \"$directory\"." >&2
    echo "Check the directory path, file name patterns, or that REDline can read the files." >&2
    exit 3
fi

echo "Thumbnails created successfully in \"$thumbnails_dir\" (created $count thumbnails)"
