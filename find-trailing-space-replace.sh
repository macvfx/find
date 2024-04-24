#!/bin/bash

# If no argument is provided, use the default directory
if [ -z "$1" ]; then
  search_directory="/Volumes/Example/Path/"
else
  search_directory="$1"
fi

find_cmd=(find "$search_directory" -depth -type d -name '*[[:space:]]' -print0)

shopt -s extglob

# Create a temporary file to store the find command's output
tmp_file=$(mktemp)
corrections=0

"${find_cmd[@]}" | tr '\n' '\0' > "$tmp_file"

while IFS= read -r -d '' source_name; do
  dest_name=${source_name%%+([[:space:]])}
  mv -- "$source_name" "$dest_name"
  ((corrections++))
done < "$tmp_file"

echo "Corrections made: $corrections"

# Remove the temporary file
rm "$tmp_file"
