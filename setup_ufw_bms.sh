#!/usr/bin/env bash

# Script Name: setup_ufw_bms.sh
# Description: Installs and configures UFW (Uncomplicated Firewall) on an Ubuntu server for Building Management System (BMS).
#              Sets default incoming/outgoing policy, allows traffic from specified IP lists (ens192, ens220),
#              allows all traffic on ens160, and enables the firewall.
#
# Usage: Run as root. Example: ./setup_ufw_bms.sh
#
# Configuration: Set LIFECYCLE to PROD or DEV. Modify ALLOWED_IPS_192 and ALLOWED_IPS_220 as needed.

set -euo pipefail

# -----------------------------------------------------------------------------
# Standalone helpers (no dependency on lib/)
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

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
    require_root

    local lifecycle="${LIFECYCLE:-PROD}"
    local allowed_ips_192=(
        "192.168.130.10"
        "192.168.130.20"
    )
    local allowed_ips_220=(
        "192.168.138.10"
        "192.168.138.20"
    )

    log --info "Updating package lists and installing UFW."
    apt update
    apt install -y ufw

    log --info "Enabling UFW."
    systemctl enable ufw
    ufw --force enable

    log --info "Setting default policies based on lifecycle ($lifecycle)."
    if [[ "$lifecycle" == "PROD" ]]; then
        ufw default deny incoming
        ufw default deny outgoing
    else
        ufw default allow incoming
        ufw default allow outgoing
    fi

    log --info "Allowing all traffic on interface ens160."
    ufw allow in on ens160
    ufw allow out on ens160

    log --info "Configuring rules for ens192 based on lifecycle ($lifecycle)."
    for ip in "${allowed_ips_192[@]}"; do
        if [[ "$lifecycle" == "PROD" ]]; then
            ufw allow in on ens192 from "$ip"
            ufw allow out on ens192 to "$ip"
        else
            ufw deny in on ens192 from "$ip"
            ufw deny out on ens192 to "$ip"
        fi
    done

    log --info "Configuring rules for ens220 based on lifecycle ($lifecycle)."
    for ip in "${allowed_ips_220[@]}"; do
        if [[ "$lifecycle" == "PROD" ]]; then
            ufw allow in on ens220 from "$ip"
            ufw allow out on ens220 to "$ip"
        else
            ufw deny in on ens220 from "$ip"
            ufw deny out on ens220 to "$ip"
        fi
    done

    log --info "Enabling UFW logging and reloading."
    ufw logging on
    ufw reload

    log --info "UFW status:"
    ufw status verbose
}

main "$@"
