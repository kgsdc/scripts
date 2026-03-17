#!/usr/bin/env bash

# CIS L1 – Detect: Unattended security updates (CIS 1.2.x).
# Exit 0 = compliant, 1 = not compliant (run remediation).

set -euo pipefail

compliant=0

# Package installed
if ! dpkg -l unattended-upgrades 2>/dev/null | grep -q '^ii'; then
    echo "unattended-upgrades not installed"
    compliant=1
fi

# Service enabled
if [ $compliant -eq 0 ] && ! systemctl is-enabled --quiet unattended-upgrades 2>/dev/null; then
    echo "unattended-upgrades not enabled"
    compliant=1
fi

# Security origin in config
if [ $compliant -eq 0 ] && [ -f /etc/apt/apt.conf.d/50unattended-upgrades ]; then
    if ! grep -q '"\${distro_id}:\${distro_codename}-security"' /etc/apt/apt.conf.d/50unattended-upgrades 2>/dev/null; then
        echo "security origin not in 50unattended-upgrades"
        compliant=1
    fi
else
    if [ $compliant -eq 0 ]; then
        echo "50unattended-upgrades config missing"
        compliant=1
    fi
fi

exit $compliant
