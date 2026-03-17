# Intune Remediation Scripts

Proactive remediation script pairs (detect + remediate) for Microsoft Intune. Use these in **Endpoint security** → **Proactive remediations** (or **Reports** → **Endpoint analytics** → **Proactive remediations** in some tenants).

---

## How to use in Intune

### 1. Create a script package

1. In **Microsoft Intune admin center**: go to **Reports** → **Endpoint analytics** → **Proactive remediations**, or **Devices** → **Scripts** (depending on your tenant).
2. Click **Create script package**.
3. **Name**: e.g. `Convert legacy Office files in OneDrive`.
4. **Description**: Optional; e.g. "Detects and converts .xls/.doc/.ppt in OneDrive to .xlsx/.docx/.pptx; moves originals to converted_old."
5. **Detection script file**: Upload the `Detect-*.ps1` script (e.g. `Detect-ConvertOldOfficeFiles.ps1`).
6. **Remediation script file**: Upload the matching `Remediate-*.ps1` script (e.g. `Remediate-ConvertOldOfficeFiles.ps1`).
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
| [ConvertOldOfficeFiles](./ConvertOldOfficeFiles/) | **Windows (PowerShell)**: detects `.xls`, `.doc`, `.ppt` in OneDrive; converts to `.xlsx`/`.docx`/`.pptx` and moves originals to `converted_old`. |
| [CIS-L1-Ubuntu](./CIS-L1-Ubuntu/) | **Linux (Bash)**: CIS Level 1 Workstation controls for Ubuntu 22.04/24.04 (updates, firewall, kernel, password, audit, screen lock, SSH, disable services). Idempotent; schedule Remediate scripts directly (Linux has no auto-remediate on detect). |

Each subfolder contains **Detect** and **Remediate** script(s) plus a short README.

---

## Requirements

- **Office apps**: Excel (for .xls), Word (for .doc), and/or PowerPoint (for .ppt) as needed; conversion uses COM. Only the apps for file types you actually have need to be installed.
- **OneDrive**: Scripts run as SYSTEM and enumerate `C:\Users\<user>\OneDrive`* to find all user OneDrive folders. No user sign-in is required for detection/remediation to run.
- **Windows**: Tested on Windows 10/11.

---

## References

- [Use remediations in Microsoft Intune](https://learn.microsoft.com/en-us/mem/intune/fundamentals/remediations)
- [Proactive remediations - Create script package](https://learn.microsoft.com/en-us/mem/analytics/proactive-remediations)

