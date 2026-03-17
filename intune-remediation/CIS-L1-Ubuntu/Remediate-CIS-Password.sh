#!/usr/bin/env bash

# CIS L1 – Remediate: Password policy (CIS 5.4.x): pwquality + login.defs.
# Idempotent: replace-or-append per key; no duplicate lines.

set -euo pipefail

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

log() {
    local level="[INFO]"
    local message=""
    case "${1:-}" in
        -i|--info)  level="[INFO]";  message="${*:2}" ;;
        -w|--warn)  level="[WARN]";  message="${*:2}" ;;
        -e|--error) level="[ERROR]"; message="${*:2}" ;;
        *)          level="[INFO]";  message="$*" ;;
    esac
    echo "$(date +'%Y-%m-%d %H:%M:%S') $level - $message"
}

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "This script must be run as root" 1>&2
        exit 1
    fi
}

# Ensure key=value in file; replace if key exists, else append.
ensure_key() {
    local file="$1"
    local key="$2"
    local value="$3"
    if grep -q "^${key}" "$file" 2>/dev/null; then
        sed -i "s|^${key}.*|${key} = ${value}|" "$file"
    else
        echo "${key} = ${value}" >> "$file"
    fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
    require_root

    export DEBIAN_FRONTEND=noninteractive

    log --info "CIS Password: Ensuring libpam-pwquality is installed."
    apt-get install -y libpam-pwquality

    local pwconf="/etc/security/pwquality.conf"
    touch "$pwconf"

    ensure_key "$pwconf" "minlen" "14"
    ensure_key "$pwconf" "dcredit" "-1"
    ensure_key "$pwconf" "ucredit" "-1"
    ensure_key "$pwconf" "ocredit" "-1"
    ensure_key "$pwconf" "lcredit" "-1"

    local logindefs="/etc/login.defs"
    if [ -f "$logindefs" ]; then
        if grep -q '^PASS_MAX_DAYS' "$logindefs"; then
            sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS 90/' "$logindefs"
        else
            echo 'PASS_MAX_DAYS 90' >> "$logindefs"
        fi
        if grep -q '^PASS_MIN_DAYS' "$logindefs"; then
            sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS 1/' "$logindefs"
        else
            echo 'PASS_MIN_DAYS 1' >> "$logindefs"
        fi
    fi

    log --info "CIS Password: Remediation complete."
}

main "$@"
