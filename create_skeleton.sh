#!/bin/bash

# Create an empty copy of a directory hierarchy. Files and symbolic links are
# deliberately not copied.

set -euo pipefail

MODE="folder"
MAX_DEPTH=""

usage() {
    cat <<'EOF'
Usage: create_skeleton.sh [options] <source_folder> <destination> [max_depth]

Copy the source folder's directory hierarchy to a destination, without files.
The destination itself represents the source root folder.

Options:
  -m, --mode folder|zip  Create a folder tree (default) or a ZIP archive
  -d, --depth NUMBER     Copy at most NUMBER levels below the source root
                         (default: all levels; 0 creates only the root)
  -h, --help             Show this help

Examples:
  create_skeleton.sh "/Volumes/Media/Project" "/tmp/Project Skeleton"
  create_skeleton.sh --depth 3 source destination
  create_skeleton.sh --mode zip source "/tmp/Project Skeleton.zip"
EOF
}

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        -m|--mode)
            [ "$#" -ge 2 ] || die "$1 requires folder or zip."
            MODE="$2"
            shift 2
            ;;
        -d|--depth)
            [ "$#" -ge 2 ] || die "$1 requires a non-negative integer."
            MAX_DEPTH="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        -*)
            die "Unknown option: $1"
            ;;
        *)
            break
            ;;
    esac
done

[ "$#" -ge 2 ] && [ "$#" -le 3 ] || {
    usage >&2
    exit 1
}

SOURCE_PATH="$1"
DEST_PATH="$2"
if [ "$#" -eq 3 ]; then
    [ -z "$MAX_DEPTH" ] || die "Specify depth either with --depth or as the third argument, not both."
    MAX_DEPTH="$3"
fi

[ "$MODE" = "folder" ] || [ "$MODE" = "zip" ] || \
    die "Mode must be 'folder' or 'zip'."

if [ -n "$MAX_DEPTH" ]; then
    case "$MAX_DEPTH" in
        *[!0-9]*|'') die "Depth must be a non-negative integer." ;;
    esac
fi

[ -d "$SOURCE_PATH" ] || \
    die "Source path '$SOURCE_PATH' does not exist or is not a directory."

# Resolve the source once so relative paths and trailing slashes are harmless.
SOURCE_ABS="$(cd "$SOURCE_PATH" && pwd -P)"

directory_depth() {
    local relative_path="$1"
    local depth=1

    while [[ "$relative_path" == */* ]]; do
        relative_path="${relative_path#*/}"
        depth=$((depth + 1))
    done
    printf '%s\n' "$depth"
}

build_skeleton() {
    local source_root="$1"
    local destination_root="$2"
    local entry relative depth

    mkdir -p "$destination_root"

    # -type d does not follow symbolic links. This prevents a link in the source
    # from unexpectedly copying a directory hierarchy outside the source tree.
    while IFS= read -r -d '' entry; do
        [ "$entry" = "$source_root" ] && continue

        relative="${entry#"$source_root"/}"
        if [ -n "$MAX_DEPTH" ]; then
            depth="$(directory_depth "$relative")"
            [ "$depth" -le "$MAX_DEPTH" ] || continue
        fi

        mkdir -p "$destination_root/$relative"
    done < <(find "$source_root" -type d -print0)
}

if [ "$MODE" = "folder" ]; then
    # Resolve the destination before walking the source. Creating a destination
    # inside the source would otherwise make the traversal copy its own output.
    DEST_PATH="${DEST_PATH%/}"
    [ -n "$DEST_PATH" ] || die "Destination cannot be the filesystem root."
    DEST_PARENT="$(dirname "$DEST_PATH")"
    DEST_NAME="$(basename "$DEST_PATH")"
    mkdir -p "$DEST_PARENT"
    DEST_PARENT_ABS="$(cd "$DEST_PARENT" && pwd -P)"
    DEST_ABS="$DEST_PARENT_ABS/$DEST_NAME"

    case "$DEST_ABS/" in
        "$SOURCE_ABS/"*) die "Destination must not be the source or be inside it." ;;
    esac

    if [ -d "$DEST_ABS" ] && \
       [ -n "$(find "$DEST_ABS" -mindepth 1 -print -quit)" ]; then
        die "Destination '$DEST_ABS' is not empty."
    elif [ -e "$DEST_ABS" ] && [ ! -d "$DEST_ABS" ]; then
        die "Destination '$DEST_ABS' exists and is not a directory."
    fi

    build_skeleton "$SOURCE_ABS" "$DEST_ABS"

    FOLDER_COUNT="$(find "$DEST_ABS" -type d | wc -l | tr -d ' ')"
    printf 'Skeleton created: %s\n' "$DEST_ABS"
    printf 'Folders created (including root): %s\n' "$FOLDER_COUNT"
else
    command -v zip >/dev/null 2>&1 || die "The 'zip' command is required for ZIP mode."

    case "$DEST_PATH" in
        *.zip) ZIP_PATH="$DEST_PATH" ;;
        *) ZIP_PATH="$DEST_PATH.zip" ;;
    esac
    ZIP_PATH="${ZIP_PATH%/}"
    ZIP_PARENT="$(dirname "$ZIP_PATH")"
    ZIP_NAME="$(basename "$ZIP_PATH")"
    ROOT_NAME="${ZIP_NAME%.zip}"
    [ -n "$ROOT_NAME" ] || die "ZIP destination must have a filename."
    mkdir -p "$ZIP_PARENT"
    ZIP_PARENT_ABS="$(cd "$ZIP_PARENT" && pwd -P)"
    ZIP_ABS="$ZIP_PARENT_ABS/$ZIP_NAME"
    [ ! -e "$ZIP_ABS" ] || die "ZIP destination '$ZIP_ABS' already exists."

    TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/create-skeleton.XXXXXX")"
    trap 'rm -rf "$TEMP_ROOT"' EXIT
    build_skeleton "$SOURCE_ABS" "$TEMP_ROOT/$ROOT_NAME"
    (cd "$TEMP_ROOT" && zip -q -r "$ZIP_ABS" "$ROOT_NAME")

    printf 'Skeleton archive created: %s\n' "$ZIP_ABS"
fi
