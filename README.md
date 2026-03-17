# scripts

[![GitHub](https://img.shields.io/badge/GitHub-kgsdc%2Fscripts-181717?logo=github)](https://github.com/kgsdc/scripts)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20Windows-lightgrey?logo=linux&logoWidth=20)](https://github.com/kgsdc/scripts)
[![Shell](https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Ansible](https://img.shields.io/badge/Ansible-EE0000?logo=ansible&logoColor=white)](https://www.ansible.com/)
[![PowerShell](https://img.shields.io/badge/PowerShell-5391FE?logo=powershell&logoColor=white)](https://docs.microsoft.com/en-us/powershell/)
[![License](https://img.shields.io/badge/License-Internal%20Use-blue)](./README.md)

Automation and deployment scripts for Linux and Windows: syslog/CEF collectors, Microsoft stack installers, firewall setup, and OneDrive file conversion.

## Quick start

- **Linux:** Most scripts require `root`. Copy and run, or use Ansible for multi-host.
- **Ansible:** Copy `ansible/inventory.example.yml` → `inventory.yml` and `ansible/group_vars/syslog_servers.example.yml` → `group_vars/syslog_servers.yml`, then run the playbook.

---

## Linux scripts

| Script | Description |
|--------|-------------|
| **bootstrap-syslog-enhanced.sh** | Installs CEF/Syslog collector (Azure Sentinel), log cleanup jobs, and cron for maintenance & Azure Monitor agent restart. |
| **install_mdatp.sh** | Installs Microsoft Defender for Endpoint (mdatp) on Ubuntu. |
| **install_intune.sh** | Installs Microsoft Intune portal on Ubuntu. |
| **install_teams.sh** | Installs Microsoft Teams on Ubuntu. |
| **setup_ufw_bms.sh** | Configures UFW for BMS (Building Management System) with allowed IP lists. |
| **setup_firewalld_bms.sh** | Configures firewalld for BMS with allowed IP lists. |

All bash scripts use `set -euo pipefail`, include logging, and are standalone (no shared lib dependency).

---

## Ansible playbooks

| Playbook | Description |
|----------|-------------|
| **ansible/bootstrap_syslog_enhanced.yml** | Deploys and runs the syslog-enhanced bootstrap across `syslog_servers`. Supports CEF or AMA collector; configurable cleanup and cron. |

**Usage:**

```bash
ansible-playbook -i inventory.yml ansible/bootstrap_syslog_enhanced.yml
# With CEF: -e "collector_type=cef" -e "workspace_id=..." -e "primary_key=..."
```

**Setup:** Copy `ansible/inventory.example.yml` and `ansible/group_vars/syslog_servers.example.yml` to `inventory.yml` and `group_vars/syslog_servers.yml`, then edit as needed.

---

## PowerShell / Intune

**OneDrive Office file conversion** (legacy .xls/.doc/.ppt → .xlsx/.docx/.pptx): use the **Intune proactive remediation** scripts in **[intune-remediation/](./intune-remediation/)** (detect + remediate). They run as SYSTEM and handle all user OneDrive folders.

---

## Intune remediation scripts

Detect/remediate script pairs for **Microsoft Intune** (Proactive remediations). Run in SYSTEM context; no user sign-in required.

| Folder | Purpose |
|--------|---------|
| **[intune-remediation/](./intune-remediation/)** | How to use in Intune, assignments, encoding. |
| **[intune-remediation/ConvertOldOfficeFiles/](./intune-remediation/ConvertOldOfficeFiles/)** | One pack for all: detect `.xls`/`.doc`/`.ppt` in OneDrive → convert to `.xlsx`/`.docx`/`.pptx`, move originals to `converted_old`. |

See **[intune-remediation/README.md](./intune-remediation/README.md)** for creating script packages, assigning to groups, and monitoring. Each subfolder has its own README.

---

## Branch workflow

- **feature/*** — New work; commit and push here first.
- **dev** — Integration branch; merge feature branches, then run tests.
- **main** — Production; updated by merging from `dev`.

```bash
# Example: add changes on feature, then promote to dev and main
git checkout -b feature/your-feature
git add -A && git commit -m "Your message"
git push -u origin feature/your-feature
git checkout main && git checkout -b dev    # if dev doesn’t exist
git checkout dev && git merge feature/your-feature && git push origin dev
git checkout main && git merge dev && git push origin main
```

---

*Scripts are provided as-is; use in line with your organization’s policies and licensing.*
