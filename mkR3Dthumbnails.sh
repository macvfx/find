#!/bin/bash

# Check if at least one argument is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <directory_path>"
    exit 1
fi

# Directory where .r3d or .R3D files are located
directory="$1"

# Check if directory exists
if [ ! -d "$directory" ]; then
    echo "Directory '$directory' not found."
    exit 1
fi

# Create Thumbnails directory if it doesn't exist
thumbnails_dir="$directory/Thumbnails"
if [ ! -d "$thumbnails_dir" ]; then
    mkdir "$thumbnails_dir"
fi

# Find .r3d or .R3D files and create thumbnails
find "$directory" -type f \( -iname "*.r3d" -o -iname "*.R3D" \) -print0 | while IFS= read -r -d '' r3dfile; do
    r3d_filename=$(basename "$r3dfile")
    thumbnail_filename="${r3d_filename%.*}"
    thumbnail_path="$thumbnails_dir/$thumbnail_filename"
    REDline --i "$r3dfile" --o "$thumbnail_path" --pad 0 --format 3 --frameCount 1
    echo "Created thumbnail: $thumbnail_path"
done

echo "Thumbnails created successfully in $thumbnails_dir"
