#!/usr/bin/env bash

# CIS L1 – Custom Compliance discovery script for Intune.
# Outputs a single JSON line with cis_workstation_essentials = Compliant | NonCompliant.
# Use with compliance.json in Intune Custom Compliance policy.
# If other Detect-*.sh scripts are in the same directory, runs them; else runs minimal inline checks.

set -euo pipefail

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)}"
compliant="Compliant"

run_detect_scripts() {
    for detect in Detect-CIS-Updates.sh Detect-CIS-Firewall.sh Detect-CIS-Kernel.sh \
                  Detect-CIS-Password.sh Detect-CIS-Audit.sh Detect-CIS-DisableServices.sh; do
        path="$SCRIPT_DIR/$detect"
        if [ -x "$path" ] && ! "$path" >/dev/null 2>&1; then
            return 1
        fi
    done
    return 0
}

# Prefer running pack Detect scripts when present; otherwise minimal inline checks
if [ -x "$SCRIPT_DIR/Detect-CIS-Updates.sh" ]; then
    run_detect_scripts || compliant="NonCompliant"
else
    # Minimal self-contained checks when deployed without other Detect scripts
    dpkg -l unattended-upgrades 2>/dev/null | grep -q '^ii' || compliant="NonCompliant"
    command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q 'Status: active' || compliant="NonCompliant"
    [ -f /etc/sysctl.d/99-cis-workstation.conf ] || compliant="NonCompliant"
    systemctl is-active --quiet auditd 2>/dev/null || compliant="NonCompliant"
fi

echo "{\"cis_workstation_essentials\": \"$compliant\"}"
