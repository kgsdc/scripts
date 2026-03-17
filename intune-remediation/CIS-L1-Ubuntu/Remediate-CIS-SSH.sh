#!/usr/bin/env bash

# CIS L1 – Remediate: SSH server hardening when sshd is installed (CIS SSH section).
# Idempotent: replace-or-append in /etc/ssh/sshd_config. No-op if SSH not installed.

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

# Ensure directive in sshd_config: add or replace first occurrence (comment-aware)
ensure_sshd() {
    local key="$1"
    local value="$2"
    local file="/etc/ssh/sshd_config"
    if grep -qE "^${key}\s" "$file" 2>/dev/null; then
        sed -i "s/^${key}.*/${key} ${value}/" "$file"
    elif grep -qE "^#\s*${key}\s" "$file" 2>/dev/null; then
        sed -i "s/^#\s*${key}.*/${key} ${value}/" "$file"
    else
        echo "${key} ${value}" >> "$file"
    fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
    require_root

    if ! dpkg -l openssh-server 2>/dev/null | grep -q '^ii'; then
        log --info "CIS SSH: openssh-server not installed; skipping."
        exit 0
    fi

    local file="/etc/ssh/sshd_config"
    [ -f "$file" ] || touch "$file"

    ensure_sshd "PermitRootLogin" "no"
    ensure_sshd "X11Forwarding" "no"
    ensure_sshd "MaxAuthTries" "4"
    ensure_sshd "IgnoreRhosts" "yes"
    ensure_sshd "PermitEmptyPasswords" "no"
    ensure_sshd "PermitUserEnvironment" "no"
    ensure_sshd "Protocol" "2"

    # Restart sshd only if we're not in a remote SSH session (could lock out)
    if systemctl is-active --quiet ssh 2>/dev/null || systemctl is-active --quiet sshd 2>/dev/null; then
        log --info "CIS SSH: Config updated. Consider running: systemctl restart ssh (or sshd)."
    fi

    log --info "CIS SSH: Remediation complete."
}

main "$@"
