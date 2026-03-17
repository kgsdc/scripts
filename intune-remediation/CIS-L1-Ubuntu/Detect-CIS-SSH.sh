#!/usr/bin/env bash

# CIS L1 – Detect: SSH server hardening (when sshd is installed).
# Exit 0 = compliant, 1 = not compliant (run remediation).
# If openssh-server is not installed, exit 0 (nothing to harden).

set -euo pipefail

if ! dpkg -l openssh-server 2>/dev/null | grep -q '^ii'; then
    exit 0
fi

file="/etc/ssh/sshd_config"
[ -f "$file" ] || exit 1

compliant=0

check_sshd() {
    local key="$1"
    local want="$2"
    local line
    line=$(grep -E "^${key}\s" "$file" 2>/dev/null | head -1)
    if [ -z "$line" ]; then
        echo "sshd_config missing or commented: $key"
        return 1
    fi
    local current
    current=$(echo "$line" | awk '{print $2}')
    if [ "$current" != "$want" ]; then
        echo "sshd_config $key: current=$current want=$want"
        return 1
    fi
    return 0
}

check_sshd "PermitRootLogin" "no" || compliant=1
check_sshd "X11Forwarding" "no" || compliant=1
check_sshd "Protocol" "2" || compliant=1

exit $compliant
