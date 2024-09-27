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

# Find all files in the specified directory and its subdirectories
find "$directory" -type f | while read -r file; do
  # Extract the base file name from the full path
  filename=$(basename "$file")
  
  # Get the length of the file name
  name_length=${#filename}

  # Check if the file name length is greater than 140 characters
  if [ "$name_length" -gt 140 ]; then
    echo "Filename: $filename (Length: $name_length)"
  fi
done
