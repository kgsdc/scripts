#!/usr/bin/env bash

# CIS L1 – Detect: Kernel sysctl (CIS 1.5.x / 3.x).
# Exit 0 = compliant, 1 = not compliant (run remediation).

set -euo pipefail

conf="/etc/sysctl.d/99-cis-workstation.conf"
compliant=0

check_sysctl() {
    local key="$1"
    local want="$2"
    local current
    current=$(sysctl -n "$key" 2>/dev/null || echo "missing")
    if [ "$current" != "$want" ]; then
        echo "sysctl $key: current=$current want=$want"
        return 1
    fi
    return 0
}

check_sysctl "net.ipv4.conf.all.accept_redirects" "0" || compliant=1
check_sysctl "net.ipv4.conf.default.accept_redirects" "0" || compliant=1
check_sysctl "net.ipv4.conf.all.send_redirects" "0" || compliant=1
check_sysctl "net.ipv4.conf.default.send_redirects" "0" || compliant=1
check_sysctl "net.ipv4.tcp_syncookies" "1" || compliant=1
check_sysctl "fs.file-max" "65535" || compliant=1

exit $compliant
