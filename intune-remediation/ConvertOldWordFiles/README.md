# Convert Old Word Files (OneDrive)

**Intune proactive remediation**: Detects legacy `.doc` files in user OneDrive folders and converts them to `.docx`, moving originals into a local `converted_old` folder.

## Scripts

| Script | Role | Description |
|--------|------|-------------|
| `Detect-ConvertOldWordFiles.ps1` | Detection | Exits 0 if no `.doc` outside `converted_old`; exits 1 if any found. |
| `Remediate-ConvertOldWordFiles.ps1` | Remediation | Converts each `.doc` to `.docx` via Word COM; moves original to `converted_old`. |

## How to use in Intune

1. In **Proactive remediations**, create a new script package.
2. **Detection script**: Upload `Detect-ConvertOldWordFiles.ps1`.
3. **Remediation script**: Upload `Remediate-ConvertOldWordFiles.ps1`.
4. Assign to the desired device or user group.
5. See the [parent README](../README.md) for full Intune steps (assignments, run context, monitoring).

## Requirements

- Microsoft **Word** installed on the device (COM-based conversion).
- Scripts run as **SYSTEM**; all user OneDrive paths under `C:\Users` are scanned.

## Behavior

- **Detection**: Scans `C:\Users\*\OneDrive*` for `.doc` files, ignoring paths containing `\converted_old\`. If none found, device is compliant (exit 0).
- **Remediation**: For each `.doc`, opens in Word, saves as `.docx` (format 16), closes, then moves the original into a `converted_old` subfolder in the same directory.
