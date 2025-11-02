# find
## Find stuff with Unix find

### Examples of Unix Find scripts

1. **add-rm-header.sh** Add or remove a header. Defaults to shell files. File type and path and dry-run or rm can be specified. See below.
2. **filename-check** Find files with file names greater than 140 characters.
3. **filename-check-n-move** Find files with file names greater than 140 characters and move them into archive
4. **findspace-confirm.sh** Find the trailing space, log, and ask to confirm the changes before making any.
5. **find-trailing-space-replace.sh** Find directories with trailing space and rename them.
6. **find-photos-sort.sh** Find photos, get creation date using stat command, make folders and sort.
7. **find-mdls-exif.sh** Find photos, get the creation date from EXIF data, make folders and sort.
8. **mk1R3Dthumbnails.sh** make ONLY 1 image thumbnail from the r3d files found in a given RDC directory. 

## Notes

- Find files with file names greater than 140 characters (move and archive) or find trailing spaces at the end of a directory name and rewrite the name. Variant with extra logging and a confirmation step to see the list of changes before changing them. Use with caution. **Test before using. Always have backups.**
- Find photos scripts: get creation date using stat command, make folders and sort or get the creation date from EXIF data, make folders and sort
- Find all R3D files and make ONLY 1 image thumbnail from the r3d files found in a given RDC directory. Requires REDline

## Add or Remove Headers Script Notes

- Find shell scripts in the default path and add a header
- Adds header after shebang (#!) if present
- Removes header exactly if --rm is specified
- Skips duplicates
- Preserves timestamps
- Supports dry-run
- Colored output, counters, recursive search, custom file pattern/path
