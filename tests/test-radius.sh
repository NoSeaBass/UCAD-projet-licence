#!/usr/bin/env bash
# Verifie FreeRADIUS.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export PROJECT_ROOT
# shellcheck source=../scripts/lib.sh
source "${SCRIPT_DIR}/../scripts/lib.sh"
# shellcheck source=lib-test.sh
source "${SCRIPT_DIR}/lib-test.sh"

echo ""
echo ""
echo "Tests RADIUS"
echo ""

assert_service_active freeradius

# Authentification reussie
if radtest "enseignant01@$LDAP_DOMAIN" "$USER_PASSWORD" localhost 0 "$RADIUS_SHARED_SECRET" 2>/dev/null | grep -q "Access-Accept"; then
    test_ok "RADIUS Access-Accept pour enseignant01@$LDAP_DOMAIN"
else
    test_ko "RADIUS Access-Accept ECHOUE pour enseignant01@$LDAP_DOMAIN"
fi

# Delai pour eviter les collisions de cache
sleep 6

# Authentification rejetee
REJECT=$(radtest "enseignant01@$LDAP_DOMAIN" "mauvais" localhost 0 "$RADIUS_SHARED_SECRET" 2>&1 || true)
if echo "$REJECT" | grep -q "Access-Reject"; then
    test_ok "RADIUS Access-Reject pour mauvais mot de passe"
else
    test_ko "RADIUS Access-Reject ECHOUE"
fi
