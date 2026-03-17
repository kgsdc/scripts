#!/usr/bin/env bash

# CIS L1 – Detect: UFW default deny incoming, allow outgoing (CIS 3.6.x).
# Exit 0 = compliant, 1 = not compliant (run remediation).

set -euo pipefail

compliant=0

if ! command -v ufw &>/dev/null; then
    echo "ufw not installed"
    exit 1
fi

if ! ufw status 2>/dev/null | grep -q 'Status: active'; then
    echo "ufw not active"
    compliant=1
fi

# Default incoming deny
if [ $compliant -eq 0 ]; then
    default_in=$(ufw status verbose 2>/dev/null | grep -E '^Default:' | awk '{print $2}' || true)
    if [ "$default_in" != "deny" ]; then
        echo "default incoming not deny"
        compliant=1
    fi
fi

# Default outgoing allow
if [ $compliant -eq 0 ]; then
    default_out=$(ufw status verbose 2>/dev/null | grep -E '^Default:' | awk '{print $4}' || true)
    if [ "$default_out" != "allow" ]; then
        echo "default outgoing not allow"
        compliant=1
    fi
fi

exit $compliant
