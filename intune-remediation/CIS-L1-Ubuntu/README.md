# CIS Level 1 Workstation – Ubuntu (Intune remediation scripts)

Idempotent Bash script pairs (Detect + Remediate) for CIS Level 1 Workstation controls on corporate Ubuntu laptops. Designed for **Ubuntu 22.04 / 24.04 LTS Desktop**. Safe to run on a schedule (e.g. daily); remediations only apply changes when the system is not already compliant.

---

## Linux vs Windows in Intune

- **Windows**: Proactive remediations run detection; if exit 1, Intune runs remediation automatically.
- **Linux**: Intune does **not** auto-run remediation on failed detection. You assign and **schedule the Remediate script(s)** directly (e.g. Devices → Scripts → Linux). Use Detect scripts for **Custom Compliance** (reporting) or local testing.

---

## Control list (script pack → CIS)

| Pack | Scripts | CIS / description |
|------|---------|--------------------|
| **Updates** | Detect-CIS-Updates.sh, Remediate-CIS-Updates.sh | 1.2.x – Unattended security updates |
| **Firewall** | Detect-CIS-Firewall.sh, Remediate-CIS-Firewall.sh | 3.6.x – UFW default deny incoming, allow outgoing |
| **Kernel** | Detect-CIS-Kernel.sh, Remediate-CIS-Kernel.sh | 1.5.x / 3.x – sysctl (redirects, syncookies, fs.file-max) |
| **Password** | Detect-CIS-Password.sh, Remediate-CIS-Password.sh | 5.4.x – pwquality, login.defs (PASS_MAX_DAYS, PASS_MIN_DAYS) |
| **Audit** | Detect-CIS-Audit.sh, Remediate-CIS-Audit.sh | 4.x – auditd (and audispd-plugins) |
| **Disable-Services** | Detect-CIS-DisableServices.sh, Remediate-CIS-DisableServices.sh | Apport, Avahi, prelink |
| **ScreenLock** | Detect-CIS-ScreenLock.sh, Remediate-CIS-ScreenLock.sh | 1.8.x – GNOME screen lock, idle delay |
| **SSH** (optional) | Detect-CIS-SSH.sh, Remediate-CIS-SSH.sh | SSH server hardening when sshd is installed |

**Run-all**: `Detect-CIS-All.sh` and `Remediate-CIS-All.sh` run every pack in order (for single-assignment deployment).

---

## Idempotency rules (safe to run repeatedly)

- **Packages**: `apt-get install -y <pkg>` — no-op if already installed.
- **Services**: Check `systemctl is-active` / `is-enabled` before enable/start; only run if not already.
- **Config files**: Replace-or-append by key (sed if key exists, else append); one drop-in file per theme to avoid duplicates.
- **UFW**: Check status before setting defaults or enabling; avoid duplicate allow rules.
- **Sysctl**: Single file `/etc/sysctl.d/99-cis-workstation.conf`; overwrite that file so rerun yields same state.
- **Per-user (gsettings)**: Run as each graphical user; setting the same value again is safe.
- **No reboot in script**: At most log "Reboot recommended"; do not call `reboot` or `shutdown -r`.

---

## How to run locally

All scripts require root. From the repo root:

```bash
# Detection (exit 0 = compliant, 1 = not)
sudo ./intune-remediation/CIS-L1-Ubuntu/Detect-CIS-Updates.sh

# Remediation (idempotent)
sudo ./intune-remediation/CIS-L1-Ubuntu/Remediate-CIS-Updates.sh
```

Repeat for each pack, or use:

```bash
sudo ./intune-remediation/CIS-L1-Ubuntu/Remediate-CIS-All.sh
```

---

## How to use in Intune

### Scripts (remediation)

1. **Devices** → **Scripts** (or **Configuration** → **Scripts** for Linux).
2. **Add** → **Linux** (Bash).
3. Upload the Remediate script(s) you want (e.g. `Remediate-CIS-All.sh` or individual `Remediate-CIS-*.sh`).
4. Assign to a device or group; set **Run script as signed-in user** or **Run script as device** (root) as required. For these remediations, run as **root**.
5. Set schedule (e.g. daily). These scripts are idempotent; running them repeatedly is safe.

### Custom Compliance (reporting)

1. **Devices** → **Compliance** → **Compliance policies** → **Create policy** → **Linux**.
2. Under **Custom compliance**, add a **Discovery script** (use `Detect-CIS-All.sh` or a script that outputs JSON) and the **Compliance JSON** (see `compliance.json` in this folder).
3. Assign to the same groups. Non-compliant devices can be blocked via Conditional Access.

---

## Files in this folder

| File | Purpose |
|------|---------|
| README.md | This file |
| Detect-CIS-Updates.sh | Detection for unattended-upgrades |
| Remediate-CIS-Updates.sh | Idempotent apply: unattended-upgrades + config + enable |
| Detect-CIS-Firewall.sh | Detection for UFW |
| Remediate-CIS-Firewall.sh | Idempotent apply: UFW defaults + enable |
| Detect-CIS-Kernel.sh | Detection for sysctl settings |
| Remediate-CIS-Kernel.sh | Idempotent apply: sysctl drop-in |
| Detect-CIS-Password.sh | Detection for pwquality + login.defs |
| Remediate-CIS-Password.sh | Idempotent apply: pwquality.conf + login.defs |
| Detect-CIS-Audit.sh | Detection for auditd |
| Remediate-CIS-Audit.sh | Idempotent apply: auditd + enable |
| Detect-CIS-DisableServices.sh | Detection for Apport/Avahi/prelink |
| Remediate-CIS-DisableServices.sh | Idempotent apply: disable/mask/remove |
| Detect-CIS-ScreenLock.sh | Detection for GNOME screen lock |
| Remediate-CIS-ScreenLock.sh | Idempotent apply: gsettings per user |
| Detect-CIS-SSH.sh | Detection for SSH hardening (when sshd present) |
| Remediate-CIS-SSH.sh | Idempotent apply: sshd_config hardening |
| Detect-CIS-All.sh | Runs all Detect scripts; exit 1 if any fail |
| Remediate-CIS-All.sh | Runs all Remediate scripts in order |
| compliance.json | Custom Compliance JSON (e.g. cis_workstation_essentials) |
| Detect-CIS-Compliance.sh | Outputs JSON for Custom Compliance |

---

## References

- [CIS Ubuntu 22.04 LTS Benchmark](https://www.cisecurity.org/benchmark/ubuntu_linux)
- [Use custom Bash scripts – Intune for Linux](https://learn.microsoft.com/en-us/intune/intune-service/configuration/custom-settings-linux)
- [Custom compliance for Linux – Intune](https://learn.microsoft.com/en-us/intune/intune-service/protect/compliance-use-custom-settings)
- [Ubuntu Security Guide (USG) / CIS](https://documentation.ubuntu.com/security/compliance/usg/cis-benchmarks/) (optional; Ubuntu Pro)
