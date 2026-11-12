#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export PROJECT_ROOT
source "${SCRIPT_DIR}/lib-test.sh"

echo "Tests LDAP"

assert_service_active slapd

if ss -tln | grep -q ':636'; then
    test_ok "LDAPS ecoute sur le port 636"
else
    test_ko "LDAPS n'ecoute pas sur le port 636"
fi

if ldapsearch -x -LLL -H ldap://localhost -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" \
    -b "$LDAP_BASE_DN" -s base "(objectClass=*)" dn 2>/dev/null | grep -q "^dn: $LDAP_BASE_DN"; then
    test_ok "Base DN $LDAP_BASE_DN accessible"
else
    test_ko "Base DN $LDAP_BASE_DN inaccessible"
fi

for ou in users groups; do
    if ldapsearch -x -LLL -H ldap://localhost -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" \
        -b "ou=$ou,$LDAP_BASE_DN" -s base "(objectClass=*)" dn 2>/dev/null | grep -q "^dn:"; then
        test_ok "OU $ou existe"
    else
        test_ko "OU $ou manquante"
    fi
done

for grp in enseignants apprenants; do
    if ldapsearch -x -LLL -H ldap://localhost -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" \
        -b "cn=$grp,ou=groups,$LDAP_BASE_DN" -s base "(objectClass=*)" dn 2>/dev/null | grep -q "^dn:"; then
        test_ok "Groupe $grp existe"
    else
        test_ko "Groupe $grp manquant"
    fi
done

for user in enseignant01 enseignant02 apprenant01 apprenant02; do
    if ldapsearch -x -LLL -H ldap://localhost -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" \
        -b "uid=$user,ou=users,$LDAP_BASE_DN" -s base "(objectClass=*)" dn 2>/dev/null | grep -q "^dn:"; then
        test_ok "Utilisateur $user existe"
    else
        test_ko "Utilisateur $user manquant"
    fi
done

if ldapsearch -x -LLL -H ldap://localhost -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" \
    -b "ou=users,$LDAP_BASE_DN" "(objectClass=sambaSAMAccount)" uid 2>/dev/null | grep -q "uid: enseignant01"; then
    test_ok "Attributs Samba presents sur les utilisateurs"
else
    test_ko "Attributs Samba manquants"
fi

if getent passwd enseignant01 >/dev/null 2>&1; then
    test_ok "SSSD resout enseignant01"
else
    test_ko "SSSD ne resout pas enseignant01"
fi

if getent group enseignants >/dev/null 2>&1; then
    test_ok "SSSD resout le groupe enseignants"
else
    test_ko "SSSD ne resout pas le groupe enseignants"
fi
