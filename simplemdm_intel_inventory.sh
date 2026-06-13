#!/bin/bash
# SimpleMDM-IntelInventory.sh
# One-line Intel-only app inventory for SimpleMDM Auto Attributes.

set -u

make_temp_file() {
    TEMP_ROOT="${TMPDIR:-/tmp}"

    if [ ! -d "$TEMP_ROOT" ] || [ ! -w "$TEMP_ROOT" ]; then
        TEMP_ROOT="/tmp"
    fi

    mktemp "$TEMP_ROOT/simplemdm_intel_inventory.XXXXXX"
}

RESULTS="$(make_temp_file)"
trap 'rm -f "$RESULTS"' EXIT

APP_SEARCH_PATHS=(
    "/Applications"
    "/Applications/Utilities"
)

display_item_for_app() {
    APP="$1"

    if [ "${APP#/Applications/}" != "$APP" ]; then
        REL_PATH="${APP#/Applications/}"

        case "$REL_PATH" in
            */*)
                TOP_LEVEL="${REL_PATH%%/*}"
                REST_PATH="${REL_PATH#*/}"

                if [ "$TOP_LEVEL" = "Utilities" ] && [ "$REST_PATH" = "$(basename "$APP")" ]; then
                    basename "$APP" .app
                else
                    printf '%s\n' "$TOP_LEVEL"
                fi
                ;;
            *)
                basename "$APP" .app
                ;;
        esac
        return
    fi

    basename "$(dirname "$APP")"
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

for DIR in "${APP_SEARCH_PATHS[@]}"; do
    [ -d "$DIR" ] || continue

    find "$DIR" -name "*.app" -type d -prune -print0 2>/dev/null |
        while IFS= read -r -d '' APP; do
            EXEC_PATH="$(app_executable_path "$APP" || true)"
            [ -n "$EXEC_PATH" ] || continue

            if is_intel_only_macho "$EXEC_PATH"; then
                display_item_for_app "$APP" >> "$RESULTS"
            fi
        done
done

COUNT="$(sort -u "$RESULTS" | wc -l | tr -d ' ')"
APP_NAMES="$(sort -u "$RESULTS" | paste -sd ',' -)"

if [ -z "$APP_NAMES" ]; then
    APP_NAMES="none"
fi

printf '%s;apps=%s\n' "$COUNT" "$APP_NAMES"
