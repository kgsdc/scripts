# Intune Remediation Scripts

Proactive remediation script pairs (detect + remediate) for Microsoft Intune. Use these in **Endpoint security** → **Proactive remediations** (or **Reports** → **Endpoint analytics** → **Proactive remediations** in some tenants).

---

## How to use in Intune

### 1. Create a script package

1. In **Microsoft Intune admin center**: go to **Reports** → **Endpoint analytics** → **Proactive remediations**, or **Devices** → **Scripts** (depending on your tenant).
2. Click **Create script package**.
3. **Name**: e.g. `Convert Old Excel Files in OneDrive`.
4. **Description**: Optional; e.g. "Detects and converts .xls to .xlsx in user OneDrive; moves originals to converted_old."
5. **Detection script file**: Upload the `Detect-*.ps1` script for the remediation (e.g. `Detect-ConvertOldExcelFiles.ps1`).
6. **Remediation script file**: Upload the matching `Remediate-*.ps1` script (e.g. `Remediate-ConvertOldExcelFiles.ps1`).
7. Save.

### 2. Assign to a group

1. Open the script package you created.
2. Go to **Assignments** → **Add group**.
3. Choose the device or user group that should run the remediation (e.g. "All Windows devices" or a pilot group).
4. Save.

### 3. Run context and schedule

- Scripts run in **SYSTEM** context on the device.
- Intune runs detection on the schedule you configure (e.g. daily). If detection returns **exit 1** (issue found), the remediation script runs automatically.
- **Exit codes**: Detection must exit **0** = compliant (no action), **1** = not compliant (run remediation). Remediation typically exits 0 on success, 1 on failure.

### 4. Check results

- In the script package, open **Device status** (or **Monitor** → **Scripts** / **Proactive remediations**) to see which devices reported **Detected**, **Remediated**, or **Failed**.
- Use **Detection script output** and **Remediation script output** for troubleshooting.

---

## Script encoding

- Save scripts as **UTF-8** (without BOM if your policy checks signatures). Intune runs PowerShell and captures stdout; avoid BOM if you see encoding issues.

---

## Available remediations

| Folder | Purpose |
|--------|---------|
| [ConvertOldExcelFiles](./ConvertOldExcelFiles/) | Detect legacy `.xls` in OneDrive; convert to `.xlsx` and move originals to `converted_old`. |
| [ConvertOldWordFiles](./ConvertOldWordFiles/) | Detect legacy `.doc` in OneDrive; convert to `.docx` and move originals to `converted_old`. |

Each subfolder contains a **Detect** and **Remediate** script plus a short README.

---

## Requirements

- **Excel** (for ConvertOldExcelFiles): Microsoft Excel installed on the device; conversion uses the Excel COM object.
- **Word** (for ConvertOldWordFiles): Microsoft Word installed on the device; conversion uses the Word COM object.
- **OneDrive**: Scripts run as SYSTEM and enumerate `C:\Users\<user>\OneDrive*` to find all user OneDrive folders. No user sign-in is required for detection/remediation to run.
- **Windows**: Tested on Windows 10/11.

---

## References

- [Use remediations in Microsoft Intune](https://learn.microsoft.com/en-us/mem/intune/fundamentals/remediations)
- [Proactive remediations - Create script package](https://learn.microsoft.com/en-us/mem/analytics/proactive-remediations)
