# find
## Find stuff with Unix find

### Examples of Unix Find scripts

1. **[add-rm-header.sh](add-rm-header.sh)** adds or removes an exact header line in matching files, with dry-run support. See the [notes below](#add-or-remove-headers-script-notes).
2. **[filename-check.sh](filename-check.sh)** reports filenames longer than 140 characters.
3. **[filename-check-n-move.sh](filename-check-n-move.sh)** logs filenames longer than 140 characters and can move them into a dated folder and archive it.
4. **[findspace-confirm.sh](findspace-confirm.sh)** finds directory names with trailing spaces, shows them, and asks before renaming them.
5. **[find-trailing-space-replace.sh](find-trailing-space-replace.sh)** finds and renames directory names with trailing whitespace without prompting.
6. **[find-photos-sort.sh](find-photos-sort.sh)** copies JPEG and PNG files into folders based on their filesystem creation dates.
7. **[find-mdls-exif-sort.sh](find-mdls-exif-sort.sh)** copies JPEG and PNG files into folders based on Spotlight content-creation metadata.
8. **[mk1R3Dthumbnail.sh](mk1R3Dthumbnail.sh)** uses REDline to create JPEG thumbnails from R3D media, with dry-run and verbose modes.
9. **[find_build_folders.sh](find_build_folders.sh)** scans for SwiftPM `.build` folders, creates reports, and offers cleanup and archive workflows. See [find_build_folders_README.md](find_build_folders_README.md).
10. **[find_xcode_projects_cleanup.sh](find_xcode_projects_cleanup.sh)** scans Xcode projects, cleans build artifacts, removes matching DerivedData, and can create an archive. See [find_xcode_proj_cleanup_README.md](find_xcode_proj_cleanup_README.md).
11. **[intel_inventory.sh](intel_inventory.sh)** finds Intel-only macOS apps and binaries that require Rosetta on Apple Silicon. See [intel_inventory_README.md](intel_inventory_README.md).
12. **[simplemdm_intel_inventory.sh](simplemdm_intel_inventory.sh)** emits compact Intel-only inventory for a SimpleMDM custom attribute. See [intel_inventory_README.md](intel_inventory_README.md#simplemdm-custom-attribute).
13. **[create_skeleton.sh](create_skeleton.sh)** recreates a source folder's complete directory hierarchy without copying files, with depth limits and ZIP output. See [create_skeleton_README.md](create_skeleton_README.md).

## Notes

- Find files with file names greater than 140 characters (move and archive) or find trailing spaces at the end of a directory name and rewrite the name. Variant with extra logging and a confirmation step to see the list of changes before changing them. Use with caution. **Test before using. Always have backups.**
- Find photos scripts: get creation date using stat command, make folders and sort or get the creation date from EXIF data, make folders and sort
- Find all R3D files and make ONLY 1 image thumbnail from the r3d files found in a given RDC directory. Requires REDline
- Create an empty copy of a directory hierarchy for templates, layout review, or structure-only sharing. Hidden directories are included; files and symbolic links are excluded.

## Add or Remove Headers Script Notes

- Find shell scripts in the default path and add a header
- Adds header after shebang (#!) if present
- Removes header exactly if --rm is specified
- Skips duplicates
- Preserves timestamps
- Supports dry-run
- Colored output, counters, recursive search, custom file pattern/path
