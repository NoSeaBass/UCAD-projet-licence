#!/usr/bin/env bash
# test-samba.sh
# Verifie Samba.

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
echo "Tests Samba"
echo ""

assert_service_active smbd
assert_service_active nmbd

# Syntaxe smb.conf
if testparm -s >/dev/null 2>&1; then
    test_ok "smb.conf valide"
else
    test_ko "smb.conf invalide"
fi

# pdbedit
for user in enseignant01 apprenant01; do
    if pdbedit -L 2>/dev/null | grep -q "^$user:"; then
        test_ok "Utilisateur Samba $user listable"
    else
        test_ko "Utilisateur Samba $user introuvable"
    fi
done

# Partage accessible (smbclient anonyme pour lister les partages sans mot de passe)
if smbclient -L localhost -U enseignant01%"$USER_PASSWORD" 2>/dev/null | grep -q "cours"; then
    test_ok "Partage cours visible"
else
    test_ko "Partage cours non visible"
fi

# Repertoires de partages
for share in cours tp public; do
    assert_dir_exists "$SHARES_BASE/$share"
done

# ACL
if getfacl "$SHARES_BASE/cours" 2>/dev/null | grep -q "group:enseignants:rwx"; then
    test_ok "ACL enseignants rwx sur cours"
else
    test_ko "ACL enseignants manquante sur cours"
fi

if getfacl "$SHARES_BASE/cours" 2>/dev/null | grep -q "group:apprenants:r-x"; then
    test_ok "ACL apprenants r-x sur cours"
else
    test_ko "ACL apprenants manquante sur cours"
fi
