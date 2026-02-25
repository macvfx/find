#!/usr/bin/env bash
# =============================================================================
# find_xcode_projects_cleanup.sh
# Scans for Xcode workspaces/projects, reports schemes, offers xcodebuild clean,
# and optionally removes matching DerivedData folders.
# =============================================================================

set -euo pipefail

usage() {
cat <<'EOF'

USAGE
  bash find_xcode_projects_cleanup.sh [OPTIONS] [SEARCH_ROOT] [REPORT_DIR]
  bash find_xcode_projects_cleanup.sh -h | --help

DESCRIPTION
  Scans a directory tree for Xcode containers (.xcworkspace and .xcodeproj),
  attempts to detect shared schemes using "xcodebuild -list", writes a text
  report and CSV, then interactively offers to:
    1. Run "xcodebuild ... clean" for discovered schemes
    2. Remove matching Xcode DerivedData folders
    3. Create a password-protected zip archive of SEARCH_ROOT (with cache/build excludes)

ARGUMENTS
  SEARCH_ROOT   (optional) Folder to scan. Defaults to current directory.
  REPORT_DIR    (optional) Folder for output reports. Defaults to Desktop.

OPTIONS
  --yes-clean        Run xcodebuild clean without prompting. If a container has
                     multiple schemes, all detected schemes are cleaned.
  --yes-deriveddata  Remove matching DerivedData folders without prompting.
  --yes-archive      Run archive step without initial proceed prompt.
                     If --zip-password is not provided, password prompts remain.
  --yes-all          Equivalent to: --yes-clean --yes-deriveddata --yes-archive
  --no-clean         Skip xcodebuild clean step (useful in automation)
  --no-deriveddata   Skip DerivedData removal step
  --no-archive       Skip archive step
  --zip-path PATH    Pre-fill archive output path (used by archive step)
  --zip-password PW  Use a non-interactive zip password for archive step

OUTPUT FILES
  xcode_projects_YYYY-MM-DD_HH-MM-SS.txt
  xcode_projects_YYYY-MM-DD_HH-MM-SS.csv

NOTES
  • "xcodebuild clean" removes build products for the selected scheme(s)
  • DerivedData removal is optional and safe (Xcode recreates it)
  • First build after a clean/DerivedData purge will be slower
  • If multiple schemes exist, the script prompts to choose one, all, or skip
  • The script also scans hidden .build folders to estimate recoverable SPM cache
    space under SEARCH_ROOT (read-only estimate unless you remove them elsewhere)

EXAMPLES
  # Interactive scan/clean in current folder
  bash find_xcode_projects_cleanup.sh

  # Scan all code projects, auto-run xcodebuild clean + DerivedData + archive
  bash find_xcode_projects_cleanup.sh --yes-all "~/Downloads/All Code Projects"

  # Report only (skip destructive steps) and save reports to Documents
  bash find_xcode_projects_cleanup.sh --no-clean --no-deriveddata "$HOME/Developer" "$HOME/Documents"

  # Typical summary output (example)
  #   Estimated recoverable (.build)         : 1.8 GB
  #   Estimated recoverable (DerivedData)    : 6.4 GB
  #   Estimated combined recoverable         : 8.2 GB

EOF
}

AUTO_CLEAN=0
AUTO_DERIVEDDATA=0
AUTO_ARCHIVE=0
SKIP_CLEAN=0
SKIP_DERIVEDDATA=0
SKIP_ARCHIVE=0
ZIP_PATH_ARG=""
ZIP_PASSWORD_ARG=""
POSITIONAL=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --yes-clean)
      AUTO_CLEAN=1
      shift
      ;;
    --yes-deriveddata)
      AUTO_DERIVEDDATA=1
      shift
      ;;
    --yes-archive)
      AUTO_ARCHIVE=1
      shift
      ;;
    --yes-all)
      AUTO_CLEAN=1
      AUTO_DERIVEDDATA=1
      AUTO_ARCHIVE=1
      shift
      ;;
    --no-clean)
      SKIP_CLEAN=1
      shift
      ;;
    --no-deriveddata)
      SKIP_DERIVEDDATA=1
      shift
      ;;
    --no-archive)
      SKIP_ARCHIVE=1
      shift
      ;;
    --zip-path)
      [[ $# -lt 2 ]] && { echo "Missing value for --zip-path" >&2; exit 1; }
      ZIP_PATH_ARG="$2"
      shift 2
      ;;
    --zip-password)
      [[ $# -lt 2 ]] && { echo "Missing value for --zip-password" >&2; exit 1; }
      ZIP_PASSWORD_ARG="$2"
      shift 2
      ;;
    --)
      shift
      while [[ $# -gt 0 ]]; do
        POSITIONAL+=( "$1" )
        shift
      done
      ;;
    -*)
      echo "Unknown option: $1" >&2
      echo "Run with --help for usage." >&2
      exit 1
      ;;
    *)
      POSITIONAL+=( "$1" )
      shift
      ;;
  esac
done

SEARCH_ROOT="${POSITIONAL[0]:-$PWD}"
REPORT_DIR="${POSITIONAL[1]:-$HOME/Desktop}"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
REPORT_FILE="$REPORT_DIR/xcode_projects_$TIMESTAMP.txt"
CSV_FILE="$REPORT_DIR/xcode_projects_$TIMESTAMP.csv"
DERIVED_DATA_ROOT="$HOME/Library/Developer/Xcode/DerivedData"

PRUNE_PATHS=(
  "$HOME/Library"
  "/System"
  "/Volumes"
  "/private"
  "/usr"
  "/opt"
)

human_readable_kb() {
  local kb="$1"
  if   (( kb >= 1048576 )); then printf "%.1f GB" "$(echo "scale=1; $kb/1048576" | bc)"
  elif (( kb >= 1024 ));    then printf "%.1f MB" "$(echo "scale=1; $kb/1024"    | bc)"
  else                           printf "%d KB"   "$kb"
  fi
}

safe_du_kb() {
  local path="$1"
  du -sk "$path" 2>/dev/null | awk '{print $1+0}'
}

human_readable_kb_or_zero() {
  local kb="${1:-0}"
  human_readable_kb "$kb"
}

detect_schemes() {
  local kind="$1" path="$2"
  local output
  if ! output=$(xcodebuild -list "-$kind" "$path" 2>/dev/null || true); then
    return 0
  fi
  awk '
    /^Schemes:/ { in_schemes=1; next }
    in_schemes && /^[[:space:]]*$/ { next }
    in_schemes && /^[[:space:]]+/ {
      line=$0
      sub(/^[[:space:]]+/, "", line)
      print line
      next
    }
    in_schemes { exit }
  ' <<< "$output"
}

container_type_of() {
  local path="$1"
  if [[ "$path" == *.xcworkspace ]]; then
    echo "workspace"
  else
    echo "project"
  fi
}

basename_no_ext() {
  local path="$1"
  local base
  base="$(basename "$path")"
  echo "${base%.*}"
}

collect_xcode_containers() {
  local -a raw_paths=()
  local -a find_args=("$SEARCH_ROOT")

  for p in "${PRUNE_PATHS[@]}"; do
    find_args+=( -path "$p" -prune -o )
  done
  find_args+=( -type d \( -name "*.xcworkspace" -o -name "*.xcodeproj" \) -print )

  mapfile -t raw_paths < <(
    find "${find_args[@]}" 2>/dev/null \
      | grep -v '\.xcodeproj/project\.xcworkspace$' \
      | sort
  )

  if [[ ${#raw_paths[@]} -eq 0 ]]; then
    return 0
  fi

  # Prefer workspaces when a directory contains both workspace and project(s).
  declare -A dir_has_workspace=()
  local path dir
  for path in "${raw_paths[@]}"; do
    dir="$(dirname "$path")"
    if [[ "$path" == *.xcworkspace ]]; then
      dir_has_workspace["$dir"]=1
    fi
  done

  for path in "${raw_paths[@]}"; do
    dir="$(dirname "$path")"
    if [[ "$path" == *.xcodeproj && -n "${dir_has_workspace[$dir]:-}" ]]; then
      continue
    fi
    echo "$path"
  done
}

collect_build_folders() {
  local -a find_args=("$SEARCH_ROOT")
  for p in "${PRUNE_PATHS[@]}"; do
    find_args+=( -path "$p" -prune -o )
  done
  find_args+=( -type d -name ".build" -print )
  find "${find_args[@]}" 2>/dev/null | grep -v "/.build/.build" | sort
}

echo ""
echo "=============================================="
echo "  Xcode Project / Workspace Scanner"
echo "=============================================="
echo "  Search root : $SEARCH_ROOT"
echo "  Output dir  : $REPORT_DIR"
echo "  Started     : $(date)"
echo "=============================================="
echo ""

mkdir -p "$REPORT_DIR"

echo "Scanning for Xcode containers... (this may take a moment)"
echo ""

mapfile -t CONTAINERS < <(collect_xcode_containers)
mapfile -t BUILD_FOLDERS < <(collect_build_folders || true)

if [[ ${#CONTAINERS[@]} -eq 0 ]]; then
  echo "No .xcworkspace or .xcodeproj found under: $SEARCH_ROOT"
  # Keep going long enough to report .build estimate if present.
fi

echo "Type,Container,Parent_Folder,Scheme_Count,Schemes" > "$CSV_FILE"
{
  echo "Xcode Containers Report"
  echo "Generated : $(date)"
  echo "Root      : $SEARCH_ROOT"
  echo "========================================"
  echo ""
} > "$REPORT_FILE"

declare -a CONTAINER_KINDS=()
declare -a CONTAINER_SCHEME_COUNTS=()
declare -a CONTAINER_SCHEMES_JOINED=()
declare -a CONTAINER_BASE_NAMES=()
declare -A UNIQUE_BASES=()

echo "Results:"
echo "--------"

total_containers=0
total_schemes=0

for container in "${CONTAINERS[@]}"; do
  kind="$(container_type_of "$container")"
  parent="$(basename "$(dirname "$container")")"
  base_name="$(basename_no_ext "$container")"
  mapfile -t schemes < <(detect_schemes "$kind" "$container")
  scheme_count=${#schemes[@]}
  schemes_joined=""
  if [[ $scheme_count -gt 0 ]]; then
    schemes_joined=$(printf "%s; " "${schemes[@]}")
    schemes_joined="${schemes_joined%; }"
  else
    schemes_joined="(none detected)"
  fi

  CONTAINER_KINDS+=( "$kind" )
  CONTAINER_SCHEME_COUNTS+=( "$scheme_count" )
  CONTAINER_SCHEMES_JOINED+=( "$schemes_joined" )
  CONTAINER_BASE_NAMES+=( "$base_name" )
  UNIQUE_BASES["$base_name"]=1

  total_containers=$(( total_containers + 1 ))
  total_schemes=$(( total_schemes + scheme_count ))

  printf "  %-9s  %s  [%s scheme%s]\n" \
    "$kind" "$(basename "$container")" "$scheme_count" "$([[ $scheme_count -eq 1 ]] && echo "" || echo "s")"
  printf "             %s\n" "$container"
  if [[ $scheme_count -gt 0 ]]; then
    printf "             Schemes: %s\n" "$schemes_joined"
  fi

  {
    printf "%-9s  %s\n" "Type:"   "$kind"
    printf "%-9s  %s\n" "Path:"   "$container"
    printf "%-9s  %s\n" "Parent:" "$parent"
    printf "%-9s  %s\n" "Schemes:" "$schemes_joined"
    echo ""
  } >> "$REPORT_FILE"

  esc_schemes="${schemes_joined//\"/\"\"}"
  echo "\"$kind\",\"$container\",\"$parent\",$scheme_count,\"$esc_schemes\"" >> "$CSV_FILE"
done

build_total_kb=0
for build_dir in "${BUILD_FOLDERS[@]}"; do
  kb=$(safe_du_kb "$build_dir")
  build_total_kb=$(( build_total_kb + kb ))
done

{
  echo "----------------------------------------"
  echo "  Containers   : $total_containers"
  echo "  Schemes seen : $total_schemes"
  echo "  .build dirs  : ${#BUILD_FOLDERS[@]}"
  echo "  .build size  : $(human_readable_kb "$build_total_kb")"
  echo "  Scanned      : $(date)"
  echo "----------------------------------------"
} | tee -a "$REPORT_FILE"

echo "" >> "$CSV_FILE"
echo "\"TOTAL\",\"$total_containers containers\",\"\",$total_schemes,\"\"" >> "$CSV_FILE"

echo ""
echo "  Report saved : $REPORT_FILE"
echo "  CSV saved    : $CSV_FILE"
echo ""

if [[ $total_containers -eq 0 ]]; then
  echo "No Xcode containers detected, so xcodebuild clean and DerivedData steps will be skipped."
  echo ""
fi

# =============================================================================
# STEP 2 — Offer xcodebuild clean
# =============================================================================
echo "=============================================="
echo "  Xcode Clean"
echo "=============================================="
echo "  Run xcodebuild clean on detected project/workspace schemes?"
echo "  Estimated recoverable (.build under search root): $(human_readable_kb "$build_total_kb")"
echo ""
if [[ $SKIP_CLEAN -eq 1 || $total_containers -eq 0 ]]; then
  CLEAN_CONFIRM="n"
elif [[ $AUTO_CLEAN -eq 1 ]]; then
  CLEAN_CONFIRM="y"
  echo "  Auto mode enabled (--yes-clean) — proceeding."
else
  printf "  Proceed? [y/N] "
  read -r CLEAN_CONFIRM || true
fi

declare -a CLEANED_SCHEMES=()
clean_success=0
clean_fail=0
clean_skip=0

if [[ "$CLEAN_CONFIRM" =~ ^[Yy]$ ]]; then
  echo ""

  for i in "${!CONTAINERS[@]}"; do
    container="${CONTAINERS[$i]}"
    kind="${CONTAINER_KINDS[$i]}"
    mapfile -t schemes < <(detect_schemes "$kind" "$container")

    echo "----------------------------------------"
    echo "  $(basename "$container") ($kind)"
    echo "  $container"

    if [[ ${#schemes[@]} -eq 0 ]]; then
      echo "  No shared schemes detected — skipping."
      clean_skip=$(( clean_skip + 1 ))
      continue
    fi

    declare -a selected_schemes=()
    if [[ ${#schemes[@]} -eq 1 ]]; then
      selected_schemes=( "${schemes[0]}" )
      echo "  Auto-selected scheme: ${schemes[0]}"
    else
      if [[ $AUTO_CLEAN -eq 1 ]]; then
        selected_schemes=( "${schemes[@]}" )
        echo "  Auto mode: cleaning all ${#schemes[@]} schemes."
      else
      echo "  Detected schemes:"
      for idx in "${!schemes[@]}"; do
        printf "    %d) %s\n" "$((idx+1))" "${schemes[$idx]}"
      done
      echo "    a) All schemes"
      echo "    s) Skip"
      printf "  Select [a/s/number]: "
      read -r scheme_choice || true
      case "${scheme_choice:-s}" in
        [Aa])
          selected_schemes=( "${schemes[@]}" )
          ;;
        [Ss]|"")
          echo "  Skipped."
          clean_skip=$(( clean_skip + 1 ))
          continue
          ;;
        *)
          if [[ "$scheme_choice" =~ ^[0-9]+$ ]] && (( scheme_choice >= 1 && scheme_choice <= ${#schemes[@]} )); then
            selected_schemes=( "${schemes[$((scheme_choice-1))]}" )
          else
            echo "  Invalid selection — skipped."
            clean_skip=$(( clean_skip + 1 ))
            continue
          fi
          ;;
      esac
      fi
    fi

    for scheme in "${selected_schemes[@]}"; do
      printf "  Cleaning scheme %-30s " "$scheme"
      if xcodebuild "-$kind" "$container" -scheme "$scheme" clean >/dev/null 2>&1; then
        echo "✓"
        clean_success=$(( clean_success + 1 ))
        CLEANED_SCHEMES+=( "$(basename "$container") :: $scheme" )
      else
        echo "✗"
        clean_fail=$(( clean_fail + 1 ))
      fi
    done
  done

  echo ""
  echo "  Clean summary"
  echo "  - Success : $clean_success scheme(s)"
  echo "  - Failed  : $clean_fail scheme(s)"
  echo "  - Skipped : $clean_skip container(s)"
  echo ""
else
  echo ""
  if [[ $SKIP_CLEAN -eq 1 ]]; then
    echo "  Skipped by option (--no-clean)."
  else
    echo "  Skipped — no xcodebuild clean commands were run."
  fi
  echo ""
fi

# =============================================================================
# STEP 3 — Offer DerivedData cleanup
# =============================================================================
echo "=============================================="
echo "  DerivedData Cleanup"
echo "=============================================="

declare -a DERIVED_MATCHES=()
declare -A DERIVED_SEEN=()
dd_total_kb=0
deriveddata_step_available=1

if [[ ! -d "$DERIVED_DATA_ROOT" ]]; then
  echo "  DerivedData folder not found:"
  echo "  $DERIVED_DATA_ROOT"
  echo ""
  echo "  Skipped."
  echo ""
  deriveddata_step_available=0
else
  for base in "${!UNIQUE_BASES[@]}"; do
    exact="$base"
    nospace="${base// /}"
    underscore="${base// /_}"

    while IFS= read -r dd; do
      [[ -z "$dd" ]] && continue
      if [[ -z "${DERIVED_SEEN[$dd]:-}" ]]; then
        DERIVED_MATCHES+=( "$dd" )
        DERIVED_SEEN["$dd"]=1
      fi
    done < <(
      find "$DERIVED_DATA_ROOT" -maxdepth 1 -mindepth 1 -type d \
        \( -name "${exact}-*" -o -name "${nospace}-*" -o -name "${underscore}-*" \) \
        -print 2>/dev/null
    )
  done

  if [[ ${#DERIVED_MATCHES[@]} -eq 0 ]]; then
    echo "  No matching DerivedData folders found for detected Xcode containers."
    echo "  Estimated recoverable (.build under search root): $(human_readable_kb "$build_total_kb")"
    echo ""
  else
    echo "  Matching DerivedData folders:"
    for dd in "${DERIVED_MATCHES[@]}"; do
      kb=$(safe_du_kb "$dd")
      dd_total_kb=$(( dd_total_kb + kb ))
      printf "  - %-10s %s\n" "$(human_readable_kb "$kb")" "$dd"
    done
    echo "  Total: $(human_readable_kb "$dd_total_kb")"
    echo ""
    echo "  Estimated recoverable (.build)      : $(human_readable_kb "$build_total_kb")"
    echo "  Estimated recoverable (DerivedData) : $(human_readable_kb "$dd_total_kb")"
    echo "  Estimated combined recoverable      : $(human_readable_kb "$((build_total_kb + dd_total_kb))")"
    echo ""
    if [[ $SKIP_DERIVEDDATA -eq 1 ]]; then
      DD_CONFIRM="n"
    elif [[ $AUTO_DERIVEDDATA -eq 1 ]]; then
      DD_CONFIRM="y"
      echo "  Auto mode enabled (--yes-deriveddata) — proceeding."
    else
      printf "  Remove these DerivedData folders? [y/N] "
      read -r DD_CONFIRM || true
    fi

    if [[ "$DD_CONFIRM" =~ ^[Yy]$ ]]; then
      echo ""
      removed_kb=0
      remove_fail=0

      for dd in "${DERIVED_MATCHES[@]}"; do
        kb=$(safe_du_kb "$dd")
        if rm -rf "$dd"; then
          removed_kb=$(( removed_kb + kb ))
          printf "  ✓ Removed %-10s %s\n" "$(human_readable_kb "$kb")" "$dd"
        else
          (( remove_fail++ )) || true
          echo "  ✗ Failed to remove $dd"
        fi
      done

      echo ""
      echo "  DerivedData cleanup summary"
      echo "  - Removed : $(human_readable_kb "$removed_kb")"
      echo "  - Failed  : $remove_fail folder(s)"
      echo ""
    else
      echo ""
      if [[ $SKIP_DERIVEDDATA -eq 1 ]]; then
        echo "  Skipped by option (--no-deriveddata)."
      else
        echo "  Skipped — no DerivedData folders removed."
      fi
      echo ""
    fi
  fi
fi

# =============================================================================
# STEP 4 — Offer password-protected zip archive of SEARCH_ROOT
# =============================================================================
echo "=============================================="
echo "  Archive Projects Folder"
echo "=============================================="
echo "  Create a password-protected zip of:"
echo "  $SEARCH_ROOT"
echo "  Excludes: .build, DerivedData, .DS_Store, __MACOSX"
echo ""

SEARCH_ROOT_ABS=$(cd "$SEARCH_ROOT" 2>/dev/null && pwd || echo "$SEARCH_ROOT")
FOLDER_SLUG=$(basename "$SEARCH_ROOT_ABS" | tr ' ' '_')
ZIP_DEFAULT="$HOME/Downloads/${FOLDER_SLUG}_$TIMESTAMP.zip"

if [[ $SKIP_ARCHIVE -eq 1 ]]; then
  ZIP_CONFIRM="n"
  ZIP_PATH="$ZIP_DEFAULT"
elif [[ $AUTO_ARCHIVE -eq 1 ]]; then
  ZIP_CONFIRM="y"
  ZIP_PATH="${ZIP_PATH_ARG:-$ZIP_DEFAULT}"
  echo "  Archive path [$ZIP_DEFAULT]: $ZIP_PATH"
  echo "  Auto mode enabled (--yes-archive) — proceeding."
else
  printf "  Archive path [%s]: " "$ZIP_DEFAULT"
  if [[ -n "$ZIP_PATH_ARG" ]]; then
    ZIP_PATH="$ZIP_PATH_ARG"
    echo "$ZIP_PATH"
  else
    read -r ZIP_PATH || true
  fi
  ZIP_PATH="${ZIP_PATH:-$ZIP_DEFAULT}"
  printf "  Proceed with archive? [y/N] "
  read -r ZIP_CONFIRM || true
fi

if [[ "$ZIP_CONFIRM" =~ ^[Yy]$ ]]; then
  echo ""
  if [[ -n "$ZIP_PASSWORD_ARG" ]]; then
    ZIP_PASS="$ZIP_PASSWORD_ARG"
    ZIP_PASS2="$ZIP_PASSWORD_ARG"
    echo "  Using password from --zip-password (non-interactive mode)."
  else
    echo "  Enter zip password (input hidden):"
    printf "  Password     : "
    read -rs ZIP_PASS || true
    echo ""
    printf "  Confirm      : "
    read -rs ZIP_PASS2 || true
    echo ""
    if [[ "$ZIP_PASS" != "$ZIP_PASS2" ]]; then
      echo ""
      echo "  ✗ Passwords do not match — archive cancelled."
      echo ""
      exit 1
    fi
  fi

  if [[ -z "$ZIP_PASS" ]]; then
    echo ""
    echo "  ✗ Password cannot be empty — archive cancelled."
    echo ""
    exit 1
  fi

  echo ""
  echo "  Zipping... (this may take a while for large folders)"
  echo ""

  if zip -r -P "$ZIP_PASS" "$ZIP_PATH" "$SEARCH_ROOT" \
    -x "*.DS_Store" \
    -x "__MACOSX" \
    -x "*/.build/*" \
    -x "*/DerivedData/*" \
    -x "*/Library/Developer/Xcode/DerivedData/*"; then
    zip_size_kb=$(safe_du_kb "$ZIP_PATH")
    zip_size_human=$(human_readable_kb "$zip_size_kb")
    echo ""
    echo "  ✓ Archive created successfully"
    echo "    Path  : $ZIP_PATH"
    echo "    Size  : $zip_size_human"
    echo ""
  else
    echo ""
    echo "  ✗ zip failed — check available disk space or path permissions."
    echo ""
    exit 1
  fi
else
  echo ""
  if [[ $SKIP_ARCHIVE -eq 1 ]]; then
    echo "  Skipped by option (--no-archive)."
  else
    echo "  Skipped — no archive created."
  fi
  echo ""
fi

echo "=============================================="
echo "  All done!"
echo "=============================================="
echo ""
