#!/usr/bin/env bash

# CIS L1 – Detect: Password policy (CIS 5.4.x): pwquality + login.defs.
# Exit 0 = compliant, 1 = not compliant (run remediation).

set -euo pipefail

compliant=0

# libpam-pwquality installed
if ! dpkg -l libpam-pwquality 2>/dev/null | grep -q '^ii'; then
    echo "libpam-pwquality not installed"
    exit 1
fi

# pwquality.conf keys
pwconf="/etc/security/pwquality.conf"
for key in minlen dcredit ucredit ocredit lcredit; do
    if ! grep -qE "^${key}" "$pwconf" 2>/dev/null; then
        echo "pwquality.conf missing: $key"
        compliant=1
    fi
done

# login.defs
logindefs="/etc/login.defs"
if [ -f "$logindefs" ]; then
    if ! grep -qE '^PASS_MAX_DAYS\s+90' "$logindefs" 2>/dev/null; then
        echo "PASS_MAX_DAYS not 90"
        compliant=1
    fi
    if ! grep -qE '^PASS_MIN_DAYS\s+1' "$logindefs" 2>/dev/null; then
        echo "PASS_MIN_DAYS not 1"
        compliant=1
    fi
else
    compliant=1
fi

exit $compliant
