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
find_cmd=(find "$search_directory" -depth -type d -name '* ' -print0)

# Enable extended globbing for pattern matching
shopt -s extglob

# Execute the find command and store the results in the temporary file
"${find_cmd[@]}" | tr '\n' '\0' > "$tmp_file"

# Display found directories and ask for confirmation before proceeding with changes
echo "The following directories have trailing spaces:"
while IFS= read -r -d '' dir_with_space; do
  echo "$dir_with_space"
done < "$tmp_file"

# Ask for confirmation to proceed with changes
read -p "Do you want to proceed with removing the trailing spaces? (y/n): " answer

# If the answer is yes, proceed with corrections
if [ "$answer" = "y" ]; then
  while IFS= read -r -d '' source_name; do
    dest_name="${source_name%"${source_name##*[![:space:]]}"}"
    mv_log="$(date +"%Y-%m-%d %H:%M:%S") - Moved '$source_name' to '$dest_name'"
    mv -- "$source_name" "$dest_name" && echo "$mv_log" >> "$log_file"
    ((corrections++))
  done < "$tmp_file"

  # Display the number of corrections made
  echo "Corrections made: $corrections"

  # Remove the temporary file
  rm "$tmp_file"
else
  echo "No changes were made."
fi
