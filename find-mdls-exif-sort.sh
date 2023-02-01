#!/bin/bash

read -p "Enter the path to search for photos: " search_path
read -p "Enter the destination path: " dest_path

# find all photo files in the specified directory and its subdirectories
find "$search_path" -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" | while read photo; do
  # get the creation date from EXIF data with mdls of the photo file
  created=$(mdls "$photo" |grep kMDItemContentCreationDate|awk '{print $3}'|uniq)

  # create a directory for the creation date in the destination path if it doesn't already exist
  if [ ! -d "$dest_path/$created" ]; then
    mkdir "$dest_path/$created"
  fi

  # move the photo file to the appropriate directory in the destination path
  #mv "$photo" "$dest_path/$created"
	cp "$photo" "$dest_path/$created"
done
