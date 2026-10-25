#!/usr/bin/env bash
# test-system.sh
# Verifie le systeme de base.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export PROJECT_ROOT

# shellcheck source=../scripts/lib.sh
source "${SCRIPT_DIR}/../scripts/lib.sh"
# shellcheck source=lib-test.sh
source "${SCRIPT_DIR}/lib-test.sh"

echo ""
echo "Tests System"
echo ""
echo ""

# Hostname
CURRENT_HOSTNAME=$(hostnamectl --static)
if [[ "$CURRENT_HOSTNAME" == "$HOSTNAME" ]]; then
    test_ok "Hostname : $CURRENT_HOSTNAME"
else
    test_ko "Hostname attendu $HOSTNAME, obtenu $CURRENT_HOSTNAME"
fi

# Timezone
CURRENT_TZ=$(timedatectl show --property=Timezone --value)
if [[ "$CURRENT_TZ" == "$TIMEZONE" ]]; then
    test_ok "Timezone : $CURRENT_TZ"
else
    test_ko "Timezone attendu $TIMEZONE, obtenu $CURRENT_TZ"
fi

# Paquets
for pkg in slapd ldap-utils samba sssd freeradius ufw; do
    if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
        test_ok "Paquet $pkg installe"
    else
        test_ko "Paquet $pkg manquant"
    fi
done
