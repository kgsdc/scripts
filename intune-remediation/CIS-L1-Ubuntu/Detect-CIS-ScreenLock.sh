#!/usr/bin/env bash

# CIS L1 – Detect: GNOME screen lock (CIS 1.8.x).
# Exit 0 = compliant, 1 = not compliant (run remediation).
# Checks first active graphical user only (or exits 0 if no graphical session).

set -euo pipefail

compliant=0

get_first_graphical_user() {
    for sid in $(loginctl list-sessions --no-legend 2>/dev/null | awk '{print $1}'); do
        type=$(loginctl show-session -p Type -p State -p Remote "$sid" 2>/dev/null || true)
        if echo "$type" | grep -q 'State=active' && echo "$type" | grep -qE 'Type=(x11|wayland)' && echo "$type" | grep -q 'Remote=no'; then
            uid=$(loginctl show-session -p User "$sid" 2>/dev/null | awk -F= '/^User=/ {print $2}')
            [ -z "$uid" ] && continue
            getent passwd "$uid" | cut -d: -f1
            return
        fi
    done
}

user=$(get_first_graphical_user)
if [ -z "$user" ]; then
    # No graphical session: consider compliant (nothing to check)
    exit 0
fi

# Check lock-enabled and idle-activation-enabled (as that user)
lock_enabled=$(runuser -l "$user" -c "gsettings get org.gnome.desktop.screensaver lock-enabled 2>/dev/null" 2>/dev/null || echo "false")
idle_enabled=$(runuser -l "$user" -c "gsettings get org.gnome.desktop.screensaver idle-activation-enabled 2>/dev/null" 2>/dev/null || echo "false")

if [ "$lock_enabled" != "true" ]; then
    echo "lock-enabled not true (user $user)"
    compliant=1
fi

if [ "$idle_enabled" != "true" ]; then
    echo "idle-activation-enabled not true (user $user)"
    compliant=1
fi

exit $compliant
