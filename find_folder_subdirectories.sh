#!/usr/bin/env bash
# Find every directory with an exact name, list the directories below each one,
# and count the distinct descendant directory names across all matches.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash find_folder_subdirectories.sh FOLDER_NAME [SEARCH_ROOT]
  bash find_folder_subdirectories.sh -h | --help

Find every directory named FOLDER_NAME under SEARCH_ROOT, list all descendant
directories within each match, and summarize descendant names and counts.

Arguments:
  FOLDER_NAME  Exact directory name to find (not a find glob pattern).
  SEARCH_ROOT  Directory to search. Defaults to the current directory.

Examples:
  bash find_folder_subdirectories.sh "Assets" ~/Code
  bash find_folder_subdirectories.sh "Deliverables" "/Volumes/Example Media"

Only directories are listed. Files and symbolic links are excluded.
EOF
}

if [[ $# -gt 0 && ( "$1" == "-h" || "$1" == "--help" ) ]]; then
  usage
  exit 0
fi

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage >&2
  exit 2
fi

TARGET_NAME=$1
SEARCH_ROOT=${2:-.}

if [[ -z "$TARGET_NAME" ]]; then
  echo "Error: FOLDER_NAME must not be empty." >&2
  exit 2
fi

if [[ ! -d "$SEARCH_ROOT" ]]; then
  echo "Error: search root is not a directory: $SEARCH_ROOT" >&2
  exit 2
fi

# Remove a trailing slash (except for /) so exact path comparisons are stable.
if [[ "$SEARCH_ROOT" != "/" ]]; then
  SEARCH_ROOT=${SEARCH_ROOT%/}
fi

MATCHES=()
UNIQUE_NAMES=()
NAME_COUNTS=()
TOTAL_SUBDIRECTORIES=0

record_name() {
  local name=$1
  local index

  for ((index = 0; index < ${#UNIQUE_NAMES[@]}; index++)); do
    if [[ "${UNIQUE_NAMES[index]}" == "$name" ]]; then
      NAME_COUNTS[index]=$((NAME_COUNTS[index] + 1))
      return
    fi
  done

  UNIQUE_NAMES+=("$name")
  NAME_COUNTS+=(1)
}

# Compare basenames in Bash so FOLDER_NAME is treated literally. find -name
# would interpret *, ?, and [ as pattern characters.
while IFS= read -r -d '' candidate; do
  candidate_name=${candidate##*/}
  [[ -z "$candidate_name" && "$candidate" == "/" ]] && candidate_name="/"

  if [[ "$candidate_name" == "$TARGET_NAME" ]]; then
    MATCHES+=("$candidate")
  fi
done < <(find "$SEARCH_ROOT" -type d -print0)

if [[ ${#MATCHES[@]} -eq 0 ]]; then
  printf 'No directories named %q were found under %q.\n' "$TARGET_NAME" "$SEARCH_ROOT"
  exit 0
fi

printf 'Found %d director' "${#MATCHES[@]}"
if [[ ${#MATCHES[@]} -eq 1 ]]; then
  printf 'y named %q:\n' "$TARGET_NAME"
else
  printf 'ies named %q:\n' "$TARGET_NAME"
fi

for match in "${MATCHES[@]}"; do
  printf '\nTarget: %q\n' "$match"
  match_count=0

  while IFS= read -r -d '' subdirectory; do
    # find includes its starting directory; list only directories below it.
    [[ "$subdirectory" == "$match" ]] && continue

    printf '  %q\n' "$subdirectory"
    subdirectory_name=${subdirectory##*/}
    record_name "$subdirectory_name"
    match_count=$((match_count + 1))
    TOTAL_SUBDIRECTORIES=$((TOTAL_SUBDIRECTORIES + 1))
  done < <(find "$match" -type d -print0)

  if [[ $match_count -eq 0 ]]; then
    echo "  (no subdirectories)"
  fi
done

printf '\nSummary\n'
printf '  Matching target folders: %d\n' "${#MATCHES[@]}"
printf '  Subdirectory occurrences: %d\n' "$TOTAL_SUBDIRECTORIES"
printf '  Unique subdirectory names: %d\n' "${#UNIQUE_NAMES[@]}"

if [[ ${#UNIQUE_NAMES[@]} -gt 0 ]]; then
  # Sort the parallel name/count arrays for stable, readable output without
  # converting names to newline-delimited data.
  for ((index = 0; index < ${#UNIQUE_NAMES[@]} - 1; index++)); do
    smallest=$index
    for ((candidate_index = index + 1; candidate_index < ${#UNIQUE_NAMES[@]}; candidate_index++)); do
      if [[ "${UNIQUE_NAMES[candidate_index]}" < "${UNIQUE_NAMES[smallest]}" ]]; then
        smallest=$candidate_index
      fi
    done

    if [[ $smallest -ne $index ]]; then
      temporary_name=${UNIQUE_NAMES[index]}
      UNIQUE_NAMES[index]=${UNIQUE_NAMES[smallest]}
      UNIQUE_NAMES[smallest]=$temporary_name

      temporary_count=${NAME_COUNTS[index]}
      NAME_COUNTS[index]=${NAME_COUNTS[smallest]}
      NAME_COUNTS[smallest]=$temporary_count
    fi
  done

  printf '\nCount  Directory name\n'
  printf '%s\n' '-----  --------------'
  for ((index = 0; index < ${#UNIQUE_NAMES[@]}; index++)); do
    printf '%5d  %q\n' "${NAME_COUNTS[index]}" "${UNIQUE_NAMES[index]}"
  done
fi
