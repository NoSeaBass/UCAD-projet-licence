#!/usr/bin/env bash
# Verifie LDAP.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export PROJECT_ROOT
source "${SCRIPT_DIR}/../scripts/lib.sh"
source "${SCRIPT_DIR}/lib-test.sh"

echo ""
echo ""
echo "Tests LDAP"
echo ""

assert_service_active slapd

# Base DN
if ldapsearch -x -LLL -H ldap://localhost -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" \
    -b "$LDAP_BASE_DN" -s base "(objectClass=*)" dn 2>/dev/null | grep -q "^dn: $LDAP_BASE_DN"; then
    test_ok "Base DN $LDAP_BASE_DN accessible"
else
    test_ko "Base DN $LDAP_BASE_DN inaccessible"
fi

# Structure DIT
for ou in users groups; do
    if ldapsearch -x -LLL -H ldap://localhost -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" \
        -b "ou=$ou,$LDAP_BASE_DN" -s base "(objectClass=*)" dn 2>/dev/null | grep -q "^dn:"; then
        test_ok "OU $ou existe"
    else
        test_ko "OU $ou manquante"
    fi
done

# Groupes
for grp in enseignants apprenants; do
    if ldapsearch -x -LLL -H ldap://localhost -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" \
        -b "cn=$grp,ou=groups,$LDAP_BASE_DN" -s base "(objectClass=*)" dn 2>/dev/null | grep -q "^dn:"; then
        test_ok "Groupe $grp existe"
    else
        test_ko "Groupe $grp manquant"
    fi
done

# Utilisateurs
for user in enseignant01 enseignant02 apprenant01 apprenant02; do
    if ldapsearch -x -LLL -H ldap://localhost -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" \
        -b "uid=$user,ou=users,$LDAP_BASE_DN" -s base "(objectClass=*)" dn 2>/dev/null | grep -q "^dn:"; then
        test_ok "Utilisateur $user existe"
    else
        test_ko "Utilisateur $user manquant"
    fi
done

# Attributs Samba
if ldapsearch -x -LLL -H ldap://localhost -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" \
    -b "ou=users,$LDAP_BASE_DN" "(objectClass=sambaSAMAccount)" uid 2>/dev/null | grep -q "uid: enseignant01"; then
    test_ok "Attributs Samba presents sur les utilisateurs"
else
    test_ko "Attributs Samba manquants"
fi

# SSSD resolution
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
