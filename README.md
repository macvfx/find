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
14. **[find_folder_subdirectories.sh](find_folder_subdirectories.sh)** finds every directory with an exact name, lists only the descendant directories within each occurrence, and counts each unique descendant name. See [find_folder_subdirectories_README.md](find_folder_subdirectories_README.md).
15. **[find-file-ext-total.sh](find-file-ext-total.sh)** counts files and adds up their real sizes for a list of extensions (default `mov mp4 mxf wav mp3`, any case) under a folder, and writes a timestamped log. See the [notes below](#file-type-counting-scripts-notes).
16. **[find-file-ext-by-year.sh](find-file-ext-by-year.sh)** does the same per year folder (for example `2021-2024`) and writes a CSV.
17. **[file-type-count2csv-EachSubFolder.sh](file-type-count2csv-EachSubFolder.sh)** counts one extension inside each top-level folder of a path and writes a CSV.
18. **[file-type-count2csv-and-du-EachSubFolder.sh](file-type-count2csv-and-du-EachSubFolder.sh)** counts one extension and measures the total size of every folder two levels down (`path/year/project`), and writes a CSV.

19. **[dev_space_cleanup.sh](dev_space_cleanup.sh)** reports and reclaims space used by Xcode and developer tools: old `.xcarchive` bundles (newest per app always kept), old device-support symbols, stale DerivedData, Xcode and SwiftPM caches, and unavailable simulators. Report-only by default; `clean` moves candidates to the Trash after asking. See the [notes below](#dev-space-cleanup-script-notes).

## Notes

- Find files with file names greater than 140 characters (move and archive) or find trailing spaces at the end of a directory name and rewrite the name. Variant with extra logging and a confirmation step to see the list of changes before changing them. Use with caution. **Test before using. Always have backups.**
- Find photos scripts: get creation date using stat command, make folders and sort or get the creation date from EXIF data, make folders and sort
- Find all R3D files and make ONLY 1 image thumbnail from the r3d files found in a given RDC directory. Requires REDline
- Create an empty copy of a directory hierarchy for templates, layout review, or structure-only sharing. Hidden directories are included; files and symbolic links are excluded.
- Find repeated folders by exact name, inspect all directory types below them, and count repeated descendant names without listing files.

## Add or Remove Headers Script Notes

- Find shell scripts in the default path and add a header
- Adds header after shebang (#!) if present
- Removes header exactly if --rm is specified
- Skips duplicates
- Preserves timestamps
- Supports dry-run
- Colored output, counters, recursive search, custom file pattern/path

## File Type Counting Scripts Notes

- All four are read-only on the folders they scan; they only write a log or CSV.
- Extension matching ignores case (`.mov` and `.MOV`) and a leading dot is accepted. Extensions may contain only letters, digits, `_`, `+` and `-`.
- Sizes are real file sizes in GB (1 GB = 1,000,000,000 bytes, as Finder shows), not `du -g`, which rounds every file or folder up to a whole GB and so overstates many small files.
- Names with commas, quotes or even newlines are counted correctly and quoted in the CSV.
- The two `file-type-count2csv-*` scripts write to a new private folder under `$TMPDIR`. Add `--share` to also copy the CSV to `/Users/Shared/<volume>_<extension>/`.
- They use macOS `stat -f` and `open`, so they are written for macOS.

## Dev Space Cleanup Script Notes

- `bash dev_space_cleanup.sh` only reports. `clean` asks per category; `clean --dry-run` lists without moving; `clean --yes` skips the questions. `--days N` sets the archive age (default 60), `--derived-days N` the DerivedData age (default 14), `--only archives,devsupport,derived,caches,simulators` limits the categories, `--list` prints every path.
- **Archives:** an `.xcarchive` holds the only dSYMs for that build, so the newest archive of each app is always kept regardless of age. Archives are grouped by app name with the timestamp or version stripped.
- **Device support:** keeps the newest OS version per device model; Xcode rebuilds an entry the next time the device is connected.
- **Simulators:** only "unavailable" devices are removed. Runtimes are listed with their sizes but never deleted by the script (`xcrun simctl runtime delete <id>`).
- Everything goes to the Trash through Finder, so it can be put back. Space is freed when the Trash is emptied.
- Uses `find` only for the DerivedData age test; archives and device support are grouped with the system `python3`.
