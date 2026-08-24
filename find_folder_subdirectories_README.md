# find_folder_subdirectories.sh

Find every occurrence of a directory with an exact name under a search path, list every descendant directory inside each match, and count the distinct descendant directory names.

Files and symbolic links are not listed or counted.

## Usage

```bash
bash find_folder_subdirectories.sh FOLDER_NAME [SEARCH_ROOT]
```

| Argument | Required | Default | Description |
|---|---:|---|---|
| `FOLDER_NAME` | Yes | — | Exact directory name to locate. Shell glob characters such as `*` are treated literally. |
| `SEARCH_ROOT` | No | Current directory | Path whose complete directory tree will be searched. |

## Examples

```bash
# Find every Assets folder under ~/Code
bash find_folder_subdirectories.sh "Assets" ~/Code

# Search a path containing spaces
bash find_folder_subdirectories.sh "Deliverables" "/Volumes/Example Media"

# Show built-in help
bash find_folder_subdirectories.sh --help
```

## Workflow

1. The script uses `find SEARCH_ROOT -type d` to scan directories without following symbolic links.
2. It compares each directory's basename with `FOLDER_NAME` as an exact literal name.
3. For every match, it uses `find` again to list all descendant directories at every depth. The matched folder itself is not included in its subdirectory list.
4. It prints the total number of matched folders, total descendant-directory occurrences, and an alphabetical count table for each unique descendant basename.

If matching target folders are nested inside one another, a descendant can be counted once for each matching target that contains it. This preserves the contents reported for every occurrence.

## Example output

```text
Found 2 directories named Assets:

Target: /Users/example/Code/AppOne/Assets
  /Users/example/Code/AppOne/Assets/Icons
  /Users/example/Code/AppOne/Assets/Photos

Target: /Users/example/Code/AppTwo/Assets
  /Users/example/Code/AppTwo/Assets/Icons
  /Users/example/Code/AppTwo/Assets/Video

Summary
  Matching target folders: 2
  Subdirectory occurrences: 4
  Unique subdirectory names: 3

Count  Directory name
-----  --------------
    2  Icons
    1  Photos
    1  Video
```

Paths are printed using Bash shell escaping so spaces, tabs, newlines, and other unusual characters remain unambiguous.

## Exit status

- `0`: search completed, including when no matching folders were found
- `2`: invalid arguments or an invalid search root
- Any other non-zero status indicates an unexpected shell or command failure
