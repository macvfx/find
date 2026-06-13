#!/bin/bash
# IntelInventory.sh
# Finds Intel-only macOS apps, with optional executable binary scanning.

set -u

FORMAT="human"
OUTPUT=""
INCLUDE_BINARIES=0
CUSTOM_PATHS=0

CUSTOM_SEARCH_PATHS=()

APP_SEARCH_PATHS=(
    "/Applications"
    "/Applications/Utilities"
)

BINARY_SEARCH_PATHS=(
    "/usr/local/bin"
    "/opt/homebrew/bin"
    "/opt/local/bin"
    "/Library"
)

usage() {
    cat <<'USAGE'
Usage:
  IntelInventory.sh [--format human|csv|mdm] [--output FILE] [--include-binaries]
                    [--path PATH ...]

Examples:
  ./IntelInventory.sh
  ./IntelInventory.sh --path /usr/local/bin --path /opt
  ./IntelInventory.sh --format csv > intel-apps.csv
  ./IntelInventory.sh --format mdm
  ssh user@mac 'bash -s -- --format csv' < IntelInventory.sh > mac-intel-apps.csv

Formats:
  human  Terminal-friendly list plus summary. Default.
  csv    CSV to stdout, or to --output FILE if provided.
  mdm    Single-line summary suitable for a custom attribute value.

By default this scans /Applications and /Applications/Utilities only. It avoids
/Users so SSH and MDM runs do not trip over user privacy/TCC boundaries.

Use --path to replace the default scope with one or more specific folders. When
--path is used, IntelInventory scans both apps and executable binaries under
those folders.
USAGE
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --format)
            FORMAT="${2:-}"
            shift 2
            ;;
        --output)
            OUTPUT="${2:-}"
            shift 2
            ;;
        --include-binaries)
            INCLUDE_BINARIES=1
            shift
            ;;
        --path)
            [ -n "${2:-}" ] || {
                echo "Missing value for --path" >&2
                exit 2
            }
            CUSTOM_PATHS=1
            CUSTOM_SEARCH_PATHS+=("$2")
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

case "$FORMAT" in
    human|csv|mdm) ;;
    *)
        echo "Invalid --format: $FORMAT" >&2
        exit 2
        ;;
esac

RESULTS="$(mktemp "${TMPDIR:-/tmp}/intel_inventory.XXXXXX")"
trap 'rm -f "$RESULTS"' EXIT

is_apple_silicon() {
    [ "$(uname -m)" = "arm64" ]
}

csv_escape() {
    printf '%s' "$1" | sed 's/"/""/g'
}

write_result() {
    TYPE="$1"
    NAME="$2"
    PATH_VALUE="$3"

    printf '%s\t%s\t%s\n' "$TYPE" "$NAME" "$PATH_VALUE" >> "$RESULTS"
}

is_intel_only_macho() {
    TARGET="$1"
    INFO="$(file "$TARGET" 2>/dev/null)"

    echo "$INFO" | grep -q "Mach-O" || return 1
    echo "$INFO" | grep -q "x86_64" || return 1
    echo "$INFO" | grep -q "arm64" && return 1

    return 0
}

app_executable_path() {
    APP="$1"
    PLIST="$APP/Contents/Info.plist"
    [ -f "$PLIST" ] || return 1

    EXEC_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$PLIST" 2>/dev/null)"
    [ -n "$EXEC_NAME" ] || return 1

    EXEC_PATH="$APP/Contents/MacOS/$EXEC_NAME"
    [ -f "$EXEC_PATH" ] || return 1

    printf '%s\n' "$EXEC_PATH"
}

scan_apps_in_paths() {
    for DIR in "$@"; do
        [ -d "$DIR" ] || continue

        find "$DIR" -name "*.app" -type d -prune -print0 2>/dev/null |
            while IFS= read -r -d '' APP; do
                EXEC_PATH="$(app_executable_path "$APP" || true)"
                [ -n "$EXEC_PATH" ] || continue

                if is_intel_only_macho "$EXEC_PATH"; then
                    APP_NAME="$(basename "$APP" .app)"
                    write_result "app" "$APP_NAME" "$APP"
                fi
            done
    done
}

scan_binaries_in_paths() {
    for DIR in "$@"; do
        [ -d "$DIR" ] || continue

        find "$DIR" -name "*.app" -type d -prune -o -type f -perm -111 -print0 2>/dev/null |
            while IFS= read -r -d '' FILE_PATH; do
                if is_intel_only_macho "$FILE_PATH"; then
                    FILE_NAME="$(basename "$FILE_PATH")"
                    write_result "binary" "$FILE_NAME" "$FILE_PATH"
                fi
            done
    done
}

emit_csv() {
    DEST="$1"

    {
        echo "Name,Type,Architecture,Requires Rosetta,Path"
        sort -u "$RESULTS" | while IFS="$(printf '\t')" read -r TYPE NAME PATH_VALUE; do
            printf '"%s","%s","x86_64 only","yes","%s"\n' \
                "$(csv_escape "$NAME")" \
                "$(csv_escape "$TYPE")" \
                "$(csv_escape "$PATH_VALUE")"
        done
    } > "$DEST"
}

emit_human() {
    COUNT="$(sort -u "$RESULTS" | wc -l | tr -d ' ')"

    echo "Intel Inventory"
    echo "Architecture: $(uname -m)"
    echo

    if ! is_apple_silicon; then
        echo "Warning: this Mac does not appear to be Apple Silicon."
        echo
    fi

    if [ "$COUNT" -eq 0 ]; then
        echo "No Intel-only items found."
    else
        echo "Intel-only items requiring Rosetta:"
        sort -u "$RESULTS" | while IFS="$(printf '\t')" read -r TYPE NAME PATH_VALUE; do
            printf '  %-7s %s\n          %s\n' "$TYPE" "$NAME" "$PATH_VALUE"
        done
    fi

    echo
    echo "Count: $COUNT"
}

emit_mdm() {
    COUNT="$(sort -u "$RESULTS" | wc -l | tr -d ' ')"
    APP_NAMES="$(sort -u "$RESULTS" | awk -F '\t' '$1 == "app" { print $2 }' | paste -sd ',' -)"

    if [ -z "$APP_NAMES" ]; then
        APP_NAMES="none"
    fi

    printf 'intel_only_count=%s;intel_only_apps=%s\n' "$COUNT" "$APP_NAMES"
}

if [ "$CUSTOM_PATHS" -eq 1 ]; then
    scan_apps_in_paths "${CUSTOM_SEARCH_PATHS[@]}"
    scan_binaries_in_paths "${CUSTOM_SEARCH_PATHS[@]}"
else
    scan_apps_in_paths "${APP_SEARCH_PATHS[@]}"

    if [ "$INCLUDE_BINARIES" -eq 1 ]; then
        scan_binaries_in_paths "${BINARY_SEARCH_PATHS[@]}"
    fi
fi

case "$FORMAT" in
    human)
        emit_human
        if [ -n "$OUTPUT" ]; then
            emit_csv "$OUTPUT"
            echo "CSV report: $OUTPUT"
        fi
        ;;
    csv)
        if [ -n "$OUTPUT" ]; then
            emit_csv "$OUTPUT"
            echo "$OUTPUT"
        else
            TEMP_CSV="$(mktemp "${TMPDIR:-/tmp}/intel_inventory_csv.XXXXXX")"
            emit_csv "$TEMP_CSV"
            cat "$TEMP_CSV"
            rm -f "$TEMP_CSV"
        fi
        ;;
    mdm)
        emit_mdm
        ;;
esac
