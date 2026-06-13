# Intel Inventory

`intel_inventory.sh` finds Intel-only macOS apps and binaries that require
Rosetta on Apple Silicon.
It is designed for three simple workflows:

- Run locally or over SSH and see the list in Terminal.
- Capture CSV output into a local report file.
- Return a compact one-line value for MDM custom inventory.

The default scan intentionally avoids `/Users` to reduce permission and TCC
friction. It scans:

- `/Applications`
- `/Applications/Utilities`

## Terminal List

```bash
./intel_inventory.sh
```

## CSV Report

```bash
./intel_inventory.sh --format csv > intel-apps.csv
```

Or write a CSV on the scanned Mac:

```bash
./intel_inventory.sh --format human --output /tmp/intel-apps.csv
```

## Scan Specific Folders

Use `--path` to replace the default scan with one or more specific folders. When
`--path` is used, the script scans both `.app` bundles and executable
Mach-O binaries under those folders.

For example, scan common package-manager binary locations:

```bash
./intel_inventory.sh --path /usr/local/bin --path /opt/homebrew/bin --path /opt/local/bin
```

Capture that targeted scan as CSV:

```bash
./intel_inventory.sh --path /usr/local/bin --path /opt/homebrew/bin --path /opt/local/bin --format csv > intel-package-bins.csv
```

## Run Over SSH

Run the script on a remote Mac and save the CSV locally:

```bash
ssh admin@remote-mac 'bash -s -- --format csv' < intel_inventory.sh > remote-mac-intel-apps.csv
```

Run a targeted scan over SSH:

```bash
ssh admin@remote-mac 'bash -s -- --path /usr/local/bin --path /opt/homebrew/bin --path /opt/local/bin --format csv' < intel_inventory.sh > remote-mac-intel-package-bins.csv
```

Run the script on a remote Mac and show the readable list in your Terminal:

```bash
ssh admin@remote-mac 'bash -s' < intel_inventory.sh
```

## MDM-Style Custom Attribute Output

```bash
./intel_inventory.sh --format mdm
```

Example output:

```text
intel_only_count=3;intel_only_apps=Example App,Legacy Tool,Old Utility
```

This is intentionally compact so it can be used by systems that store stdout
from a script as a custom inventory value.

## SimpleMDM Custom Attribute

Use `simplemdm_intel_inventory.sh` when uploading a script directly to
SimpleMDM. It has no required arguments and only prints one line, which keeps it
clean for Auto Attributes.

Suggested setup:

1. In SimpleMDM, create a custom attribute such as `intel_inventory`.
2. Add `simplemdm_intel_inventory.sh` under Scripts.
3. Create a Script Job for the target Macs.
4. Enable the option to store script output in a custom attribute on the device
   record.
5. Store the output in the `intel_inventory` custom attribute.
6. Add that custom attribute as a visible column in the Devices dashboard.

The stored value will look like:

```text
intel_only_count=3;intel_only_apps=Example App,Legacy Tool,Old Utility
```

## Optional Binary Scan

The default report focuses on apps. To include Intel-only executable binaries
from common system locations, including Homebrew and MacPorts paths:

```bash
./intel_inventory.sh --include-binaries
```

This can add noise, so it is not recommended as the default MDM inventory value.
