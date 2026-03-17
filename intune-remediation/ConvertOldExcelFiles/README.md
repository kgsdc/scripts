# Convert Old Excel Files (OneDrive)

**Intune proactive remediation**: Detects legacy `.xls` files in user OneDrive folders and converts them to `.xlsx`, moving originals into a local `converted_old` folder.

## Scripts

| Script | Role | Description |
|--------|------|-------------|
| `Detect-ConvertOldExcelFiles.ps1` | Detection | Exits 0 if no `.xls` outside `converted_old`; exits 1 if any found. |
| `Remediate-ConvertOldExcelFiles.ps1` | Remediation | Converts each `.xls` to `.xlsx` via Excel COM; moves original to `converted_old`. |

## How to use in Intune

1. In **Proactive remediations**, create a new script package.
2. **Detection script**: Upload `Detect-ConvertOldExcelFiles.ps1`.
3. **Remediation script**: Upload `Remediate-ConvertOldExcelFiles.ps1`.
4. Assign to the desired device or user group.
5. See the [parent README](../README.md) for full Intune steps (assignments, run context, monitoring).

## Requirements

- Microsoft **Excel** installed on the device (COM-based conversion).
- Scripts run as **SYSTEM**; all user OneDrive paths under `C:\Users` are scanned.

## Behavior

- **Detection**: Scans `C:\Users\*\OneDrive*` for `.xls` files, ignoring paths containing `\converted_old\`. If none found, device is compliant (exit 0).
- **Remediation**: For each `.xls`, opens in Excel, saves as `.xlsx` (format 51), closes, then moves the original into a `converted_old` subfolder in the same directory.
