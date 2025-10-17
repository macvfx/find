#!/bin/bash
# Copyright Mat X 2025 - All Rights Reserved
# Recursively add or remove a header line in matching files (macOS-safe)
# Features:
# - Adds header after shebang (#!) if present
# - Removes header exactly if --rm is specified
# - Skips duplicates
# - Preserves timestamps
# - Supports dry-run
# - Colored output, counters, recursive search, custom file pattern/path

set -o pipefail

# --- colors ---
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
RED="\033[0;31m"
RESET="\033[0m"

# --- usage ---
usage() {
    echo "Usage: $0 [--dry-run] [--rm] \"# Header text\" [start_path] [pattern]"
    echo "  --dry-run        Preview changes without writing"
    echo "  --rm             Remove matching header instead of adding"
    echo "  \"# Header text\" The exact header line to add/remove"
    echo "  start_path       Directory to start search (default: current dir)"
    echo "  pattern          File pattern to match (default: *.sh)"
    exit 1
}

# --- parse arguments ---
dry_run=false
remove_mode=false
header=""
start_path="."
pattern="*.sh"

positional=()
for arg in "$@"; do
    case "$arg" in
        --dry-run) dry_run=true ;;
        --rm|--remove) remove_mode=true ;;
        --help|-h) usage ;;
        *) positional+=("$arg") ;;
    esac
done

# first positional argument is header
if [ ${#positional[@]} -lt 1 ]; then
    usage
fi
header="${positional[0]}"
[ ${#positional[@]} -ge 2 ] && start_path="${positional[1]}"
[ ${#positional[@]} -ge 3 ] && pattern="${positional[2]}"

# --- counters ---
added=0
removed=0
skipped=0
previewed=0

# --- summary header ---
echo -e "${CYAN}Searching in:${RESET} $start_path"
echo -e "${CYAN}Pattern:     ${RESET}$pattern"
echo -e "${CYAN}Header text: ${RESET}$header"
[ "$dry_run" = true ] && echo -e "${YELLOW}Mode:        ${RESET}DRY RUN (no changes will be made)"
if [ "$remove_mode" = true ]; then
    echo -e "${RED}Action:      ${RESET}REMOVE HEADER"
else
    echo -e "${GREEN}Action:      ${RESET}ADD HEADER"
fi
echo "--------------------------------------------"

# --- main loop ---
while IFS= read -r -d '' f; do
    [ -z "$f" ] && continue
    # Record timestamp
    ts=$(stat -f "%m" "$f")

    if [ "$remove_mode" = true ]; then
        # Check if header exists
        if ! awk -v hdr="$header" '$0==hdr{found=1; exit} END{exit !found}' "$f"; then
            echo -e "${YELLOW}Skipped${RESET} $f (header not found)"
            ((skipped++))
            continue
        fi
        if [ "$dry_run" = true ]; then
            echo -e "${CYAN}[DRY RUN]${RESET} Would remove header from $f"
            ((previewed++))
            continue
        fi

        # Remove exact header line
        awk -v hdr="$header" '$0!=hdr' "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
        # Restore timestamp
        touch -t "$(date -r "$ts" +"%Y%m%d%H%M.%S")" "$f"
        echo -e "${RED}Removed header${RESET} from $f"
        ((removed++))
        continue
    fi

    # ADD mode
    # Check if header already exists
    if awk -v hdr="$header" '$0==hdr{found=1; exit} END{exit !found}' "$f"; then
        echo -e "${YELLOW}Skipped${RESET} $f (header already present)"
        ((skipped++))
        continue
    fi

    if [ "$dry_run" = true ]; then
        echo -e "${CYAN}[DRY RUN]${RESET} Would add header to $f"
        ((previewed++))
        continue
    fi

    # --- Add header after shebang ---
    first_line=$(head -n1 "$f")
    if [[ "$first_line" =~ ^#! ]]; then
        { echo "$first_line"; echo "$header"; tail -n +2 "$f"; } > "${f}.tmp"
    else
        { echo "$header"; cat "$f"; } > "${f}.tmp"
    fi

    mv "${f}.tmp" "$f"
    touch -t "$(date -r "$ts" +"%Y%m%d%H%M.%S")" "$f"
    echo -e "${GREEN}Added header${RESET} to $f"
    ((added++))
done < <(find "$start_path" -type f -name "$pattern" -print0)

# --- summary ---
echo "--------------------------------------------"
if [ "$remove_mode" = true ]; then
    if [ "$dry_run" = true ]; then
        echo -e "${CYAN}Dry-run remove summary:${RESET}"
        echo -e "  Would remove from: ${CYAN}$previewed${RESET} files"
        echo -e "  Skipped (header not found): ${YELLOW}$skipped${RESET}"
    else
        echo -e "${RED}Headers removed:${RESET} $removed"
        echo -e "${YELLOW}Skipped (header not found):${RESET} $skipped"
    fi
else
    if [ "$dry_run" = true ]; then
        echo -e "${CYAN}Dry-run add summary:${RESET}"
        echo -e "  Would add to: ${CYAN}$previewed${RESET} files"
        echo -e "  Skipped (already had header): ${YELLOW}$skipped${RESET}"
    else
        echo -e "${GREEN}Headers added:${RESET} $added"
        echo -e "${YELLOW}Skipped (already had header):${RESET} $skipped"
    fi
fi

total=$((added + removed + skipped + previewed))
echo -e "${CYAN}Total files processed:${RESET} $total"
echo "--------------------------------------------"