# Clean Up Scripts (Xcode + SwiftPM)

This folder contains interactive and automation-friendly cleanup scripts for:

- Swift Package Manager `.build` folders
- Xcode `xcodebuild clean` runs
- Xcode `DerivedData` cache cleanup
- Optional password-protected project archives (`zip`)

## Which Script To Use

### `find_build_folders.sh`
Use this when you want to:
- scan for hidden `.build` folders (Swift Package Manager build artifacts)
- estimate how much space `.build` is using
- run `swift package clean` (or delete `.build` folders where no `Package.swift` exists)
- optionally create a password-protected zip archive of the scanned folder
- zip archive step now excludes common cache/build artifacts by default:
  - `.build`
  - `DerivedData`
  - `.DS_Store`
  - `__MACOSX`

Best for:
- Swift package projects
- pre-archive cleanup of project folders
- reclaiming `.build` disk space

### `find_xcode_projects_cleanup.sh`
Use this when you want to:
- scan for `.xcodeproj` / `.xcworkspace`
- detect schemes (when `xcodebuild -list` can see them)
- run `xcodebuild clean`
- remove matching Xcode `DerivedData` folders
- optionally create a password-protected zip archive of the scanned folder
- estimate recoverable `.build` + `DerivedData` space before cleanup
- archive step excludes common cache/build artifacts by default:
  - `.build`
  - `DerivedData`
  - `.DS_Store`
  - `__MACOSX`

Best for:
- Xcode/macOS app projects
- reclaiming `DerivedData`
- cleanup before archiving or backup

## `.build` vs `DerivedData` (Important)

### `.build` (inside project trees)
- Created by Swift Package Manager
- Usually lives in a project folder as a hidden directory named `.build`
- Safe to delete
- Regenerated on next package build

### `DerivedData` (global Xcode cache)
- Created by Xcode
- Usually lives at `~/Library/Developer/Xcode/DerivedData/`
- Safe to delete
- Regenerated on next Xcode build/index

For project archiving:
- You usually want to exclude both `.build` and `DerivedData`

## Typical Cleanup Flow (Interactive)

### Option A: SwiftPM + Archive
1. Run `find_build_folders.sh`
2. Review report / CSV
3. Confirm Step 2 to clean `.build` artifacts
4. Confirm Step 3 to create a password-protected zip archive

### Option B: Xcode Projects
1. Run `find_xcode_projects_cleanup.sh`
2. Review detected projects/workspaces and schemes
3. Confirm `xcodebuild clean`
4. Confirm `DerivedData` removal
5. (Optional) confirm the zip archive step

## Automation / Non-Interactive Examples

### 1) Clean SwiftPM `.build` folders only (no archive)
```bash
bash "find_build_folders.sh" --yes-clean --no-archive "~/Downloads/All Code Projects"
```

### 2) Clean SwiftPM `.build` and create zip non-interactively (advanced)
```bash
bash "find_build_folders.sh" \
  --yes-all \
  --zip-path "~/Downloads/project_archive.zip" \
  --zip-password "REDACTED" \
  "~/Downloads/All Code Projects/P5 Archive Swift Apps"
```

Notes:
- `--zip-password` is convenient for automation but less secure (shell history/process visibility)
- Prefer the interactive password prompt when possible
- The archive step excludes `.build` and `DerivedData` paths by default to keep archives smaller/cleaner

### 3) Xcode cleanup (run `xcodebuild clean`, remove DerivedData)
```bash
bash "find_xcode_projects_cleanup.sh" --yes-all "~/Downloads/All Code Projects"
```

### 4) Xcode cleanup without archive
```bash
bash "find_xcode_projects_cleanup.sh" --yes-clean --yes-deriveddata --no-archive "~/Downloads/All Code Projects"
```

### 5) Xcode report-only mode (no changes)
```bash
bash "find_xcode_projects_cleanup.sh" --no-clean --no-deriveddata "~/Downloads/All Code Projects"
```

## Space Saved Estimates

### `find_build_folders.sh`
- Reports exact `.build` folder total size under the scan root
- Shows estimated recoverable size before cleanup

### `find_xcode_projects_cleanup.sh`
- Scans hidden `.build` folders under the scan root
- Scans matching `DerivedData` folders for detected Xcode projects
- Shows:
  - estimated recoverable `.build`
  - estimated recoverable `DerivedData`
  - estimated combined recoverable size

Example summary output:
```text
Estimated recoverable (.build)      : 1.8 GB
Estimated recoverable (DerivedData) : 6.4 GB
Estimated combined recoverable      : 8.2 GB
```

## Reports Generated

Both scripts write timestamped reports:
- human-readable `.txt`
- spreadsheet-friendly `.csv`

Default report destination:
- `~/Desktop`

You can override with the second positional argument:
```bash
bash "find_xcode_projects_cleanup.sh" "/path/to/scan" "/path/to/reports"
```

## Safety Notes

- Both scripts are read-only until you confirm cleanup/archive steps (unless using `--yes-*`)
- Deleting `.build` and `DerivedData` is safe, but the next build will be slower
- `xcodebuild clean` may fail on some projects if schemes are not shared/detectable; the script reports failures and continues
- `find_xcode_projects_cleanup.sh --yes-all` now includes the archive step too; use `--no-archive` if you only want cleanup
