#!/usr/bin/env bash

# CIS L1 – Remediate: GNOME screen lock (CIS 1.8.x): lock enabled, idle activation, idle delay.
# Idempotent: runs gsettings per user with an active graphical session. Safe to run repeatedly.

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

# Idle delay in seconds (e.g. 300 = 5 minutes)
IDLE_DELAY="${IDLE_DELAY:-300}"

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
    require_root

    local applied=0

    for sid in $(loginctl list-sessions --no-legend 2>/dev/null | awk '{print $1}'); do
        type=$(loginctl show-session -p Type -p State -p Remote "$sid" 2>/dev/null || true)
        if echo "$type" | grep -q 'State=active' && echo "$type" | grep -qE 'Type=(x11|wayland)' && echo "$type" | grep -q 'Remote=no'; then
            uid=$(loginctl show-session -p User "$sid" 2>/dev/null | awk -F= '/^User=/ {print $2}')
            [ -z "$uid" ] && continue
            user=$(getent passwd "$uid" | cut -d: -f1)
            [ -z "$user" ] && continue

            # Run gsettings as that user (need DISPLAY for the session)
            export DISPLAY=:0
            if runuser -l "$user" -c "gsettings set org.gnome.desktop.screensaver lock-enabled true 2>/dev/null" 2>/dev/null; then
                runuser -l "$user" -c "gsettings set org.gnome.desktop.screensaver idle-activation-enabled true 2>/dev/null" 2>/dev/null || true
                runuser -l "$user" -c "gsettings set org.gnome.desktop.session idle-delay $IDLE_DELAY 2>/dev/null" 2>/dev/null || true
                log --info "CIS ScreenLock: Applied for user $user."
                applied=1
            fi
        fi
    done

    if [ $applied -eq 0 ]; then
        log --warn "CIS ScreenLock: No active graphical session found; nothing applied."
    fi

    log --info "CIS ScreenLock: Remediation complete."
}

main "$@"
