# find
## Find stuff with Unix find

### Examples of Unix Find scripts

1. find-photos-sort.sh ** Find photos, get creation date using stat command, make folders and sort**
2. find-mdls-exif.sh ** Find photos, get the creation date from EXIF data, make folders and sort **
3. find-trailing-space-replace.sh ** Find directories with trailing space and rename them **
4. findspace-confirm.sh ** Find the trailing space, log, and ask to confirm the changes before making any **
5. mkR3Dthumbnails.sh ** make image thumbnails from ALL r3d files in a given directory
6. mk1R3Dthumbnails.sh ** make ONLY 1 image thumbnail from the r3d files found in a given RDC directory

## Notes

- Find photos scripts: get creation date using stat command, make folders and sort or get the creation date from EXIF data, make folders and sort
- Find trailing spaces at the end of a directory name and rewrite the name. Variant with extra logging and a confirmation step to see the list of changes before changing them. Use with caution. **Test before using. Always have backups.**
- Find all R3D files and make image thumbnails from ALL of the r3d files in a given directory **or** make ONLY 1 image thumbnail from the r3d files found in a given RDC directory
