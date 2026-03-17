#!/usr/bin/env bash

# CIS L1 – Detect: Run all CIS L1 Detect scripts. Exit 0 = all compliant, 1 = any not compliant.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)

for detect in Detect-CIS-Updates.sh Detect-CIS-Firewall.sh Detect-CIS-Kernel.sh \
             Detect-CIS-Password.sh Detect-CIS-Audit.sh Detect-CIS-DisableServices.sh \
             Detect-CIS-ScreenLock.sh Detect-CIS-SSH.sh; do
    path="$SCRIPT_DIR/$detect"
    if [ -x "$path" ]; then
        if ! "$path" >/dev/null 2>&1; then
            echo "Failed: $detect"
            exit 1
        fi
    fi
done

exit 0
