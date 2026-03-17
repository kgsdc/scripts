#!/usr/bin/env bash

# CIS L1 – Detect: Apport disabled, Avahi disabled, prelink not installed.
# Exit 0 = compliant, 1 = not compliant (run remediation).

set -euo pipefail

compliant=0

# Apport: must be disabled/masked if present
if systemctl list-unit-files --type=service 2>/dev/null | grep -q 'apport.service'; then
    if systemctl is-enabled --quiet apport 2>/dev/null; then
        echo "Apport is enabled"
        compliant=1
    fi
fi

# Avahi: must be disabled if present
if systemctl list-unit-files --type=service 2>/dev/null | grep -q 'avahi-daemon.service'; then
    if systemctl is-enabled --quiet avahi-daemon 2>/dev/null; then
        echo "Avahi is enabled"
        compliant=1
    fi
fi

# Prelink: must not be installed
if dpkg -l prelink 2>/dev/null | grep -q '^ii'; then
    echo "prelink is installed"
    compliant=1
fi

exit $compliant
