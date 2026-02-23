#!/usr/bin/env bash
# =============================================================================
# find_build_folders.sh
# Finds all hidden .build folders under a search root, reports size/location,
# and exports both a human-readable report and a CSV.
# =============================================================================

set -euo pipefail

# ---------------- Usage ------------------------------------------------------
usage() {
cat <<'EOF'

USAGE
  bash find_build_folders.sh [SEARCH_ROOT] [REPORT_DIR]
  bash find_build_folders.sh -h | --help

DESCRIPTION
  Scans a directory tree for hidden .build folders created by Swift Package
  Manager (SPM). Reports each folder's size and location, exports a
  human-readable .txt report and a .csv file, then interactively offers to:
    1. Run "swift package clean" on each discovered project
    2. Create a password-protected .zip archive of the search root

ARGUMENTS
  SEARCH_ROOT   (optional) Absolute path to the folder to scan.
                Defaults to your home directory: $HOME
                Wrap paths containing spaces in quotes.

  REPORT_DIR    (optional) Absolute path where the .txt report and .csv
                will be saved. Defaults to your Desktop: $HOME/Desktop
                The directory will be created if it does not exist.

OUTPUT FILES
  Both files are saved to REPORT_DIR and timestamped:
    build_folders_YYYY-MM-DD_HH-MM-SS.txt   Human-readable aligned report
    build_folders_YYYY-MM-DD_HH-MM-SS.csv   Spreadsheet-importable table

  CSV columns:
    Size            Human-readable size  (e.g. "90.6 MB")
    Size_KB         Raw kilobytes        (e.g. 92774)
    Path            Full path to the .build folder
    Parent_Project  Name of the containing project folder
    (final row)     TOTAL row with grand total KB and folder count

INTERACTIVE STEPS (run after the scan)
  Step 2 — Swift Package Clean
    Prompts before making any changes. For each .build folder found:
      • If a Package.swift exists in the parent → runs:
          swift package clean --package-path <project_dir>
      • If no Package.swift is found → asks to delete the .build
        folder directly with rm -rf (covers non-SPM projects)
    Reports bytes freed per project and a grand total.

  Step 3 — Password-Protected Zip Archive
    Prompts for a destination path (default: ~/Downloads/<FolderName>_<timestamp>.zip)
    Prompts for a password (hidden input, confirmed twice).
    Runs: zip -er <archive.zip> <SEARCH_ROOT> -x "*.DS_Store" -x "__MACOSX"
    Reports final archive path and size on success.

SKIPPED DIRECTORIES
  The following paths are pruned from the scan to save time:
    ~/Library   /System   /Volumes   /private   /usr   /opt

EXAMPLES
  # Scan your entire home directory, save reports to Desktop
  bash find_build_folders.sh

  # Scan a specific projects folder
  bash find_build_folders.sh ~/Developer

  # Scan a path with spaces, save reports to Documents
  bash find_build_folders.sh "/Users/xavier/Downloads/All Code Projects" ~/Documents

  # Show this help message
  bash find_build_folders.sh --help

NOTES
  • Safe to re-run — scan is read-only until you confirm Step 2 or Step 3
  • The .build folder is always safe to delete; SPM regenerates it on next build
  • Add .build/ to your .gitignore to prevent committing build artifacts
  • First build after a clean will be slower (module cache must be rebuilt)
  • zip -er uses legacy ZipCrypto encryption; for stronger AES-256 encryption
    consider: 7z a -tzip -mem=AES256 -p archive.zip <folder>

EOF
}

# Show help if -h or --help passed
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

# ---------------- Configuration ----------------------------------------------
SEARCH_ROOT="${1:-$HOME}"                        # First arg or $HOME
REPORT_DIR="${2:-$HOME/Desktop}"                 # Second arg or Desktop
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
REPORT_FILE="$REPORT_DIR/build_folders_$TIMESTAMP.txt"
CSV_FILE="$REPORT_DIR/build_folders_$TIMESTAMP.csv"

# Dirs to skip entirely (saves time on irrelevant or system paths)
PRUNE_PATHS=(
  "$HOME/Library"
  "/System"
  "/Volumes"
  "/private"
  "/usr"
  "/opt"
)

# ---------------- Helpers ----------------------------------------------------
# Convert raw KB (from du -sk) to human-readable with units
human_readable() {
  local kb="$1"
  if   (( kb >= 1048576 )); then printf "%.1f GB" "$(echo "scale=1; $kb/1048576" | bc)"
  elif (( kb >= 1024 ));    then printf "%.1f MB" "$(echo "scale=1; $kb/1024"    | bc)"
  else                           printf "%d KB"   "$kb"
  fi
}

# ---------------- Main -------------------------------------------------------
echo ""
echo "=============================================="
echo "  .build Folder Scanner"
echo "=============================================="
echo "  Search root : $SEARCH_ROOT"
echo "  Output dir  : $REPORT_DIR"
echo "  Started     : $(date)"
echo "=============================================="
echo ""

# Verify output dir exists
mkdir -p "$REPORT_DIR"

# Collect .build folder paths, skipping nested .build folders inside .build
echo "Scanning for .build folders... (this may take a moment)"
echo ""

mapfile -t BUILD_FOLDERS < <(
  # Build find args as an array to correctly handle spaces in paths
  local_args=("$SEARCH_ROOT")
  for p in "${PRUNE_PATHS[@]}"; do
    local_args+=( -path "$p" -prune -o )
  done
  local_args+=( -type d -name ".build" -print )

  find "${local_args[@]}" 2>/dev/null \
    | grep -v "/.build/.build" \
    | sort
)

TOTAL_FOLDERS=${#BUILD_FOLDERS[@]}

if [[ $TOTAL_FOLDERS -eq 0 ]]; then
  echo "No .build folders found under: $SEARCH_ROOT"
  exit 0
fi

# Write CSV header
echo "Size,Size_KB,Path,Parent_Project" > "$CSV_FILE"

# Write report header
{
  echo ".build Folder Report"
  echo "Generated : $(date)"
  echo "Root      : $SEARCH_ROOT"
  echo "========================================"
  echo ""
} > "$REPORT_FILE"

# Process each folder
GRAND_TOTAL_KB=0
declare -a TABLE_ROWS

echo "Results:"
echo "--------"

for folder in "${BUILD_FOLDERS[@]}"; do
  # Get size in KB (cross-platform: du -sk gives KB on macOS)
  size_kb=$(du -sk "$folder" 2>/dev/null | awk '{print $1}')
  size_human=$(human_readable "$size_kb")
  parent=$(dirname "$folder")
  project_name=$(basename "$parent")

  GRAND_TOTAL_KB=$(( GRAND_TOTAL_KB + size_kb ))

  # Pad human size for aligned output
  size_padded=$(printf "%-10s" "$size_human")

  TABLE_ROWS+=( "$size_padded  $folder" )

  # Print to terminal
  printf "  %-10s  %s\n" "$size_human" "$folder"

  # Append to report
  printf "  %-10s  %s\n" "$size_human" "$folder" >> "$REPORT_FILE"

  # Escape path for CSV (wrap in quotes to handle spaces/commas)
  echo "\"$size_human\",$size_kb,\"$folder\",\"$project_name\"" >> "$CSV_FILE"
done

GRAND_TOTAL_HUMAN=$(human_readable $GRAND_TOTAL_KB)

# Footer
FOOTER="
----------------------------------------
  Folders found : $TOTAL_FOLDERS
  Total size    : $GRAND_TOTAL_HUMAN
  Scanned       : $(date)
----------------------------------------"

echo "$FOOTER"
echo "$FOOTER" >> "$REPORT_FILE"

# CSV summary rows
echo "" >> "$CSV_FILE"
echo "\"TOTAL\",$GRAND_TOTAL_KB,\"$TOTAL_FOLDERS folders\",\"\"" >> "$CSV_FILE"

echo ""
echo "  Report saved : $REPORT_FILE"
echo "  CSV saved    : $CSV_FILE"
echo ""

# =============================================================================
# STEP 2 — Offer to run swift package clean on each project
# =============================================================================
echo "=============================================="
echo "  Swift Package Clean"
echo "=============================================="
echo "  Run 'swift package clean' on each project?"
echo "  This removes .build artifacts (~$GRAND_TOTAL_HUMAN recoverable)"
echo ""
printf "  Proceed? [y/N] "
read -r CLEAN_CONFIRM || true

if [[ "$CLEAN_CONFIRM" =~ ^[Yy]$ ]]; then
  echo ""
  CLEANED_KB=0
  CLEAN_ERRORS=0

  for folder in "${BUILD_FOLDERS[@]}"; do
    project_dir=$(dirname "$folder")
    project_name=$(basename "$project_dir")
    size_before_kb=$(du -sk "$folder" 2>/dev/null | awk '{print $1}')

    printf "  %-40s  " "$project_name"

    # swift package clean requires a Package.swift in the directory
    if [[ -f "$project_dir/Package.swift" ]]; then
      if swift package clean --package-path "$project_dir" 2>/dev/null; then
        size_after_kb=$(du -sk "$folder" 2>/dev/null | awk '{print $1}')
        freed_kb=$(( size_before_kb - size_after_kb ))
        freed_human=$(human_readable $freed_kb)
        CLEANED_KB=$(( CLEANED_KB + freed_kb ))
        printf "✓ cleaned  (freed %s)\n" "$freed_human"
      else
        printf "✗ clean failed\n"
        (( CLEAN_ERRORS++ )) || true
      fi
    else
      # Fallback: no Package.swift found, offer rm -rf
      printf "⚠ no Package.swift — delete .build directly? [y/N] "
      read -r DELETE_CONFIRM || true
      if [[ "$DELETE_CONFIRM" =~ ^[Yy]$ ]]; then
        rm -rf "$folder"
        CLEANED_KB=$(( CLEANED_KB + size_before_kb ))
        printf "  %-40s  ✓ deleted\n" "$project_name"
      else
        printf "  %-40s  — skipped\n" "$project_name"
      fi
    fi
  done

  CLEANED_HUMAN=$(human_readable $CLEANED_KB)
  echo ""
  echo "  Total freed : $CLEANED_HUMAN"
  [[ $CLEAN_ERRORS -gt 0 ]] && echo "  Errors      : $CLEAN_ERRORS project(s) failed — check manually"
  echo ""
else
  echo ""
  echo "  Skipped — no changes made."
  echo ""
fi

# =============================================================================
# STEP 3 — Offer to create a password-protected zip archive of the search root
# =============================================================================
echo "=============================================="
echo "  Archive Projects Folder"
echo "=============================================="
echo "  Create a password-protected zip of:"
echo "  $SEARCH_ROOT"
echo ""

# Suggest a zip filename based on the folder name + timestamp
FOLDER_SLUG=$(basename "$SEARCH_ROOT" | tr ' ' '_')
ZIP_DEFAULT="$HOME/Downloads/${FOLDER_SLUG}_$TIMESTAMP.zip"

printf "  Archive path [%s]: " "$ZIP_DEFAULT"
read -r ZIP_PATH || true
ZIP_PATH="${ZIP_PATH:-$ZIP_DEFAULT}"

printf "  Proceed with archive? [y/N] "
read -r ZIP_CONFIRM || true

if [[ "$ZIP_CONFIRM" =~ ^[Yy]$ ]]; then
  echo ""
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

  if [[ -z "$ZIP_PASS" ]]; then
    echo ""
    echo "  ✗ Password cannot be empty — archive cancelled."
    echo ""
    exit 1
  fi

  echo ""
  echo "  Zipping... (this may take a while for large folders)"
  echo ""

  # zip -er : recurse into dirs, encrypt with AES password prompt bypass via -P
  # Using -P is less secure (visible in ps) so we pipe via stdin with -P workaround
  # Best practice on macOS: pass password via env to avoid shell history exposure
  if zip -er "$ZIP_PATH" "$SEARCH_ROOT" -x "*.DS_Store" -x "__MACOSX" <<< "$ZIP_PASS"; then
    zip_size_kb=$(du -sk "$ZIP_PATH" 2>/dev/null | awk '{print $1}')
    zip_size_human=$(human_readable $zip_size_kb)
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
  echo "  Skipped — no archive created."
  echo ""
fi

echo "=============================================="
echo "  All done!"
echo "=============================================="
echo ""
