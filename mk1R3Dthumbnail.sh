#!/bin/bash

# Check if at least one argument is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <directory_path>"
    exit 1
fi

# Directory where .RDC folders are located
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

# Find .RDC folders and process contained .R3D files
find "$directory" -type d -name "*.RDC" -print0 | while IFS= read -r -d '' rdc_folder; do
    r3d_file=$(find "$rdc_folder" -maxdepth 1 -type f \( -iname "*.r3d" -o -iname "*.R3D" \))
    if [ -n "$r3d_file" ]; then
        r3d_filename=$(basename "$r3d_file")
        thumbnail_filename="${r3d_filename%.*}"
        thumbnail_path="$thumbnails_dir/$thumbnail_filename"
        REDline --i "$r3d_file" --o "$thumbnail_path" --pad 0 --format 3 --frameCount 1
        echo "Created thumbnail: $thumbnail_path"
    else
        echo "No .R3D file found in folder: $rdc_folder"
    fi
done

echo "Thumbnails created successfully in $thumbnails_dir"
