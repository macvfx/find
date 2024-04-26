#!/bin/bash

# If no argument is provided, use the default directory
if [ -z "$1" ]; then
  search_directory="/Users/Shared/"
else
  search_directory="$1"
fi

# Log file
log_file="$search_directory/correction.log"

# Initialize corrections counter
corrections=0

# Find directories with spaces and store the results in a temporary file
tmp_file=$(mktemp)

# Find command with depth, type, and name options to search for directories with spaces
find_cmd=(find "$search_directory" -depth -type d -name '*[[:space:]]' -print0)

# Enable extended globbing for pattern matching
shopt -s extglob

"${find_cmd[@]}" | tr '\n' '\0' > "$tmp_file"

# Process each found directory
while IFS= read -r -d '' source_name; do
  dest_name=${source_name%%+([[:space:]])}
  mv_log="$(date +"%Y-%m-%d %H:%M:%S") - Moved '$source_name' to '$dest_name'"
  mv -- "$source_name" "$dest_name" && echo "$mv_log" >> "$log_file"
  ((corrections++))
done < "$tmp_file"

# Display the number of corrections made
echo "Corrections made: $corrections"

# Remove the temporary file
rm "$tmp_file"
