# Create Skeleton Folder

`create_skeleton.sh` recreates a source folder's directory hierarchy without
copying any files. It is useful for preparing an empty project template,
reviewing a directory layout, or sharing a folder structure without its
contents.

The source folder is read only. The script creates either an empty folder tree
or a ZIP archive containing that tree.

## What it copies

- The complete directory hierarchy by default.
- Empty directories.
- Hidden directories, including names beginning with `.`.
- Directory names containing spaces, newlines, and other shell-sensitive
  characters.

It does **not** copy:

- Regular files, including hidden files.
- Symbolic links, even when they point to directories.
- Permissions, ownership, timestamps, extended attributes, or other metadata.

The destination folder itself represents the source root. For example, if the
source contains `Editorial/Audio`, this command:

```bash
./create_skeleton.sh source "Example Project Skeleton"
```

creates:

```text
Example Project Skeleton/
└── Editorial/
    └── Audio/
```

It does not create an additional `source` folder inside the destination.

## Requirements

- Bash
- Standard `find`, `mkdir`, `dirname`, and `basename` commands
- The `zip` command when using ZIP mode

The script is directly executable on macOS. From this folder, confirm its
permissions if necessary:

```bash
chmod +x create_skeleton.sh
```

## Usage

```text
create_skeleton.sh [options] <source_folder> <destination> [max_depth]
```

The simplest form copies every subfolder:

```bash
./create_skeleton.sh \
  "/Users/example/Example_Project" \
  "/Users/example/Example_Project_Skeleton"
```

Paths containing spaces must be quoted. Run the built-in help at any time:

```bash
./create_skeleton.sh --help
```

## Options

| Option | Meaning |
| --- | --- |
| `-m folder`, `--mode folder` | Create an empty folder tree. This is the default. |
| `-m zip`, `--mode zip` | Create a ZIP archive containing the empty folder tree. |
| `-d NUMBER`, `--depth NUMBER` | Limit output to `NUMBER` levels below the source root. |
| `-h`, `--help` | Display command help. |
| `--` | Stop option parsing, useful when a source or destination name begins with `-`. |

Depth must be a non-negative integer:

- `0` creates only the destination root.
- `1` includes direct child directories.
- `2` includes children and grandchildren.
- Omitting depth includes all directory levels.

For compatibility, depth can also be supplied as the third positional
argument:

```bash
./create_skeleton.sh source destination 3
```

Do not use both `--depth` and the positional depth argument in the same
command.

## Common workflows

### Create a complete empty folder tree

```bash
./create_skeleton.sh \
  "/Users/example/Example_Project" \
  "/Users/example/Example_Project_Skeleton"
```

Workflow:

1. Confirm that the source path is an existing directory.
2. Choose a new destination or an existing empty directory.
3. Run the command.
4. Review the reported destination and folder count.
5. Inspect the destination before using it as a template.

### Limit the copied hierarchy

This example includes only the first three levels below the source root:

```bash
./create_skeleton.sh --depth 3 \
  "/Users/example/Example_Project" \
  "/Users/example/Example_Project_Skeleton"
```

### Create a ZIP archive

```bash
./create_skeleton.sh --mode zip \
  "/Users/example/Example_Project" \
  "/Users/example/Example_Project_Skeleton.zip"
```

If the destination does not end in `.zip`, the script adds the extension. The
archive contains one top-level directory named after the ZIP file. For example,
`Example_Project_Skeleton.zip` contains `Example_Project_Skeleton/`.

### Use a path beginning with a hyphen

```bash
./create_skeleton.sh -- "-example-source" "-example-destination"
```

## How the script works

1. It validates the mode, source, destination, and optional depth.
2. It resolves the physical source path.
3. In folder mode, it confirms that the destination is safe and empty.
4. It walks only real directories beneath the source without following symbolic
   links.
5. It creates each relative directory path beneath the destination.
6. In ZIP mode, it builds the hierarchy in a temporary directory, archives it,
   and removes the temporary directory.
7. It reports the created folder or archive path.

## Safety behavior

- The source is never modified.
- A folder destination cannot be the source or be located inside the source.
  This prevents the script from discovering and copying its own output.
- An existing folder destination must be empty. The script refuses to mix a
  skeleton with existing content.
- ZIP mode refuses to overwrite an existing archive.
- Symbolic links are not followed, preventing traversal into directories outside
  the selected source tree.
- Temporary ZIP staging data is removed when the script exits.

If validation fails, the script prints an `Error:` message and exits without
building the skeleton. Correct the reported path or option and run it again.

## Verifying the result

List the directories in a folder result:

```bash
find "/Users/example/Example_Project_Skeleton" -type d -print
```

Confirm that the result contains no files or links. This command should print
nothing:

```bash
find "/Users/example/Example_Project_Skeleton" ! -type d -print
```

Inspect a ZIP archive without extracting it:

```bash
unzip -Z1 "/Users/example/Example_Project_Skeleton.zip"
```

## Exit status

- `0`: the skeleton or help output completed successfully.
- Non-zero: an argument, path, safety check, required command, or creation step
  failed.
