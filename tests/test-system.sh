#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export PROJECT_ROOT

source "${SCRIPT_DIR}/lib-test.sh"

echo "Tests System"

CURRENT_HOSTNAME=$(hostnamectl --static)
if [[ "$CURRENT_HOSTNAME" == "$HOSTNAME" ]]; then
    test_ok "Hostname : $CURRENT_HOSTNAME"
else
    test_ko "Hostname attendu $HOSTNAME, obtenu $CURRENT_HOSTNAME"
fi

for pkg in slapd ldap-utils samba sssd freeradius ufw; do
    if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
        test_ok "Paquet $pkg installe"
    else
        test_ko "Paquet $pkg manquant"
    fi
done
