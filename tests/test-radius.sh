#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export PROJECT_ROOT
source "${SCRIPT_DIR}/lib-test.sh"

echo "Tests RADIUS"

assert_service_active freeradius

if [[ -z "${RADIUS_SHARED_SECRET:-}" ]]; then
    test_ko "Secret RADIUS non configure"
else
    if radtest "enseignant01@$LDAP_DOMAIN" "$USER_PASSWORD" localhost 0 "$RADIUS_SHARED_SECRET" 2>/dev/null | grep -q "Access-Accept"; then
        test_ok "RADIUS Access-Accept pour enseignant01@$LDAP_DOMAIN"
    else
        test_ko "RADIUS Access-Accept ECHOUE pour enseignant01@$LDAP_DOMAIN"
    fi

    REJECT=$(radtest "enseignant01@$LDAP_DOMAIN" "mauvais" localhost 0 "$RADIUS_SHARED_SECRET" 2>&1 || true)
    if echo "$REJECT" | grep -q "Access-Reject"; then
        test_ok "RADIUS Access-Reject pour mauvais mot de passe"
    else
        test_ko "RADIUS Access-Reject ECHOUE"
    fi
fi
