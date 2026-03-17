# Convert Old Office Files (OneDrive)

**Intune proactive remediation**: One script pair for **all** legacy Microsoft Office files in OneDrive. Detects `.xls`, `.doc`, and `.ppt`; converts them to `.xlsx`, `.docx`, and `.pptx`; moves originals into a local `converted_old` folder.

Using a single detect/remediate pack for all Office types is the usual approach: less to maintain, one assignment in Intune, and consistent behavior.

## Scripts

| Script | Role | Description |
|--------|------|-------------|
| `Detect-ConvertOldOfficeFiles.ps1` | Detection | Scans all user OneDrive folders for `.xls`, `.doc`, `.ppt` (excluding `converted_old`). Exit 0 = compliant, 1 = remediation needed. |
| `Remediate-ConvertOldOfficeFiles.ps1` | Remediation | Converts each file with the right Office COM app (Excel/Word/PowerPoint), then moves the original to `converted_old`. |

## How to use in Intune

1. In **Proactive remediations**, create a new script package (e.g. "Convert legacy Office files in OneDrive").
2. **Detection script**: Upload `Detect-ConvertOldOfficeFiles.ps1`.
3. **Remediation script**: Upload `Remediate-ConvertOldOfficeFiles.ps1`.
4. Assign to the desired device or user group.
5. See the [parent README](../README.md) for full Intune steps (assignments, run context, monitoring).

## Requirements

- **Excel** for `.xls` → `.xlsx`
- **Word** for `.doc` → `.docx`
- **PowerPoint** for `.ppt` → `.pptx`

Scripts run as **SYSTEM**; all user OneDrive paths under `C:\Users` are scanned. Only the apps for file types actually present need to be installed.

## Behavior

- **Detection**: Scans `C:\Users\*\OneDrive*` for `*.xls`, `*.doc`, `*.ppt`, ignoring paths containing `\converted_old\`. If any are found, exit 1.
- **Remediation**: For each file, opens in the matching app (Excel/Word/PowerPoint), saves as Open XML (51/16/24), closes the app, moves the original into a `converted_old` subfolder in the same directory. Collision names get a suffix (e.g. `Report (1).xlsx`).

## Extensions

To change which file types are included, edit the `$LegacyExtensions` array in both the **Detect** and **Remediate** scripts (e.g. remove `"*.ppt"` if you don’t want PowerPoint conversion).
