#!/usr/bin/env bash

# CIS L1 – Detect: auditd (CIS 4.x).
# Exit 0 = compliant, 1 = not compliant (run remediation).

set -euo pipefail

compliant=0

if ! dpkg -l auditd 2>/dev/null | grep -q '^ii'; then
    echo "auditd not installed"
    exit 1
fi

if ! systemctl is-enabled --quiet auditd 2>/dev/null; then
    echo "auditd not enabled"
    compliant=1
fi

if ! systemctl is-active --quiet auditd 2>/dev/null; then
    echo "auditd not active"
    compliant=1
fi

exit $compliant
