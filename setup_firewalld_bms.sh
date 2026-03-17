#!/usr/bin/env bash

# Script Name: setup_firewalld_bms.sh
# Description: Installs and configures firewalld on an Ubuntu server for Building Management System (BMS).
#              Sets default incoming policy, allows traffic from specified IP lists (ens192, ens220),
#              allows all traffic on ens160, and enables the firewall.
#
# Usage: Run as root. Example: ./setup_firewalld_bms.sh
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
        # Add more IPs as needed
    )
    local allowed_ips_220=(
        "192.168.138.10"
        "192.168.138.20"
        # Add more IPs as needed
    )

    log --info "Updating package lists and installing firewalld."
    apt update
    apt install -y firewalld

    log --info "Starting and enabling firewalld."
    systemctl start firewalld
    systemctl enable firewalld

    log --info "Setting default policies based on lifecycle ($lifecycle)."
    if [[ "$lifecycle" == "PROD" ]]; then
        firewall-cmd --set-default-zone=block
    else
        firewall-cmd --set-default-zone=public
    fi

    log --info "Allowing all traffic on interface ens160."
    firewall-cmd --zone=trusted --add-interface=ens160 --permanent

    log --info "Configuring rules for ens192 based on lifecycle ($lifecycle)."
    for ip in "${allowed_ips_192[@]}"; do
        if [[ "$lifecycle" == "PROD" ]]; then
            firewall-cmd --zone=trusted --add-source="$ip" --permanent
        else
            firewall-cmd --zone=drop --add-source="$ip" --permanent
        fi
    done

    log --info "Configuring rules for ens220 based on lifecycle ($lifecycle)."
    for ip in "${allowed_ips_220[@]}"; do
        if [[ "$lifecycle" == "PROD" ]]; then
            firewall-cmd --zone=trusted --add-source="$ip" --permanent
        else
            firewall-cmd --zone=drop --add-source="$ip" --permanent
        fi
    done

    log --info "Reloading firewalld to apply changes."
    firewall-cmd --reload

    log --info "Firewalld status:"
    firewall-cmd --list-all-zones
}

main "$@"
