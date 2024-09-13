#!/bin/bash

# Check if a directory path is provided as an argument
if [ -z "$1" ]; then
  # If no argument is given, ask the user for the directory path
  read -rp "Please enter the path to the directory: " directory
else
  # Use the provided argument as the directory path
  directory="$1"
fi

# Ensure the directory exists
if [ ! -d "$directory" ]; then
  echo "The provided directory does not exist. Please check the path and try again."
  exit 1
fi

# Get today's date
today_date=$(date +%Y-%m-%d)

# Define the log file path
log_file="$directory/${today_date}_WARNING.log"

# Initialize log file
echo "Logging files with long names to: "$log_file" > "$log_file""

# Find all files in the specified directory and its subdirectories
find "$directory" -type f | while read -r file; do
  # Extract the base file name from the full path
  filename=$(basename "$file")

  # Get the length of the file name
  name_length=${#filename}

  # Check if the file name length is greater than 140 characters
  if [ "$name_length" -gt 140 ]; then
    echo "$file" | tee -a "$log_file"
  fi
done

# Ask user if they want to proceed with moving the files
read -rp "Do you want to move these files to a new folder and archive them? (y/n): " proceed

if [[ "$proceed" =~ ^[Yy]$ ]]; then
  # Create a new directory with today's date
  new_folder="$directory/$today_date"
  mkdir -p "$new_folder"

  # Move the logged files to the new directory while preserving their structure
  while IFS= read -r file_path; do
    # Construct the target path under the new folder
    target_path="$new_folder${file_path#$directory}"
    
    # Create the target directory if it doesn't exist
    mkdir -p "$(dirname "$target_path")"
    echo "$file_path" "$target_path"
    # Move the file to the target directory
    mv "$file_path" "$target_path"
  done < "$log_file"

  # Create a tar archive of the new folder
  tar -czf "$directory/${today_date}_archive.tar.gz" -C "$directory" "$today_date"

  echo "Files have been moved to $new_folder and archived as ${today_date}_archive.tar.gz."
else
  echo "Operation canceled."
fi
