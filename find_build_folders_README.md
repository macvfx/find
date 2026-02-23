# find_build_folders.sh

A bash utility for macOS that scans a directory tree for hidden `.build` folders created by Swift Package Manager (SPM), reports their sizes and locations, exports a report and CSV, then interactively offers to clean each project and archive the entire folder as a password-protected zip.

---

## Usage

```bash
bash find_build_folders.sh [SEARCH_ROOT] [REPORT_DIR]
bash find_build_folders.sh -h | --help
```

---

## Arguments

| Argument | Required | Default | Description |
|---|---|---|---|
| `SEARCH_ROOT` | No | `$HOME` | Absolute path to the folder to scan. Wrap paths containing spaces in quotes. |
| `REPORT_DIR` | No | `$HOME/Desktop` | Absolute path where the `.txt` report and `.csv` will be saved. Created automatically if it does not exist. |

---

## Examples

```bash
# Scan your entire home directory, save reports to Desktop
bash find_build_folders.sh

# Scan a specific projects folder
bash find_build_folders.sh ~/Developer

# Scan a path with spaces, save reports to Documents
bash find_build_folders.sh "/Users/dev/Downloads/All Code Projects" ~/Documents

# Show help
bash find_build_folders.sh --help
```

---

## Output Files

Both files are saved to `REPORT_DIR` and automatically timestamped:

```
build_folders_YYYY-MM-DD_HH-MM-SS.txt
build_folders_YYYY-MM-DD_HH-MM-SS.csv
```

### .txt — Human-Readable Report

Aligned table of every `.build` folder found with its size and full path, plus a summary footer showing total folder count and combined size.

```
.build Folder Report
Generated : Sun Feb 22 21:42:48 PST 2026
Root      : /Users/dev/Downloads/All Code Projects
========================================

  90.6 MB     /Users/dev/.../Media Conversion/.build
  48.7 MB     /Users/dev/.../P5MediaCore/.build
  4 KB        /Users/dev/.../P5ExportCore/.build

----------------------------------------
  Folders found : 3
  Total size    : 139.3 MB
----------------------------------------
```

### .csv — Spreadsheet-Importable Table

Importable directly into Excel, Numbers, or Google Sheets.

| Column | Example | Description |
|---|---|---|
| `Size` | `90.6 MB` | Human-readable size |
| `Size_KB` | `92774` | Raw size in kilobytes for sorting/math |
| `Path` | `/Users/.../Media Conversion/.build` | Full path to the `.build` folder |
| `Parent_Project` | `Media Conversion` | Name of the containing project folder |
| *(final row)* | `TOTAL` | Grand total KB and folder count |

---

## Interactive Steps

The script runs fully read-only during the scan, then walks through two optional interactive steps.

### Step 2 — Swift Package Clean

Prompts before making any changes. Shows total recoverable space upfront.

For each `.build` folder found:

- **`Package.swift` found** → runs `swift package clean --package-path <project_dir>` and reports bytes freed
- **No `Package.swift`** → asks whether to delete the `.build` folder directly with `rm -rf` (handles non-SPM build artifacts)
- **Clean fails** → logs the error count and continues to the next project

```
==============================================
  Swift Package Clean
==============================================
  Run 'swift package clean' on each project?
  This removes .build artifacts (~139.3 MB recoverable)

  Proceed? [y/N]

  Media Conversion              ✓ cleaned  (freed 90.6 MB)
  P5MediaCore                    ✓ cleaned  (freed 48.7 MB)
  P5ExportCore                    ✓ cleaned  (freed 4 KB)

  Total freed : 139.3 MB
```

### Step 3 — Password-Protected Zip Archive

Creates an encrypted zip of the entire `SEARCH_ROOT` folder.

- Suggests a default archive filename: `<FolderName>_YYYY-MM-DD_HH-MM-SS.zip` saved to `~/Downloads`
- Accepts a custom output path (press Enter to use the default)
- Hidden password entry with confirmation — refuses to proceed on mismatch or empty password
- Excludes `.DS_Store` and `__MACOSX` noise automatically
- Reports final archive path and size on success

```
==============================================
  Archive Projects Folder
==============================================
  Create a password-protected zip of:
  /Users/dev/Downloads/Code
  Archive path [~/Downloads/Code_2026-02-22.zip]:
  Proceed with archive? [y/N]

  Enter zip password (input hidden):
  Password     : ········
  Confirm      : ········

  Zipping... (this may take a while for large folders)

  ✓ Archive created successfully
    Path  : ~/Downloads/Code_2026-02-22.zip
    Size  : 412.3 MB
```

The zip command used:
```bash
zip -er archive.zip <SEARCH_ROOT> -x "*.DS_Store" -x "__MACOSX"
```

> **Note:** `zip -er` uses legacy ZipCrypto encryption. For stronger AES-256 encryption, use:
> ```bash
> 7zz a -tzip -mem=AES256 -p archive.zip <folder>
> ```
> **Note:** `zip` is built in in macOS. Use Mac Ports or Brew to install 7zip
---

## Skipped Directories

The following paths are pruned automatically to keep scans fast and focused on project code:

| Path | Reason |
|---|---|
| `~/Library` | macOS user application data |
| `/System` | macOS system files |
| `/Volumes` | Mounted external drives |
| `/private` | macOS private system data |
| `/usr` | Unix system binaries |
| `/opt` | Third-party installs (Homebrew, MacPorts) |

---

## What is a `.build` folder?

The `.build` folder is generated automatically by Swift Package Manager when you run `swift build` or `swift test`. It is entirely safe to delete — SPM regenerates it on the next build.

### Typical size breakdown

| Subfolder | Typical Size | Contents |
|---|---|---|
| `ModuleCache/` | 100–200 MB | Pre-compiled Apple SDK modules (Foundation, SwiftUI, etc.) — the main size driver |
| `index/` | 10–30 MB | Source index for Xcode code navigation |
| `*.xctest` | 1–10 MB | Compiled test bundles |
| `*.build/` | 1–5 MB | Compiled object files and `.swiftmodule` for each target |

### Should `.build` be in `.gitignore`?

Yes — always. Add the following to your project's `.gitignore`:

```
.build/
```

Committing `.build` adds hundreds of megabytes of machine-specific, generated files that vary by architecture and Xcode version and will cause merge conflicts.

---

## Notes

- **Safe to re-run** — the scan phase is entirely read-only; no changes are made until you confirm Step 2 or Step 3
- **First build after a clean will be slower** — the module cache needs to be rebuilt from scratch; subsequent builds return to normal speed
- **Answering `N`** to either interactive step skips it cleanly with no changes made
- All output filenames are timestamped so repeated runs never overwrite previous reports
