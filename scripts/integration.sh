#!/usr/bin/env bash
# Configure SSSD, applique les permissions sur les partages, integre Samba.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export PROJECT_ROOT
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_root
load_config

if [[ -f /etc/projet-soutenance/service-accounts.env ]]; then
    # shellcheck disable=SC1091
    source /etc/projet-soutenance/service-accounts.env
else
    die "Fichier /etc/projet-soutenance/service-accounts.env introuvable. Executer openldap.sh d'abord."
fi

# Etape 1 : Configurer SSSD
log_info "Configuration de SSSD..."

backup_file /etc/sssd/sssd.conf

cat > /etc/sssd/sssd.conf <<EOF
[sssd]
services = nss, pam
config_file_version = 2
domains = $LDAP_DOMAIN

[nss]
filter_users = root
filter_groups = root

[pam]

[domain/$LDAP_DOMAIN]
id_provider = ldap
auth_provider = ldap
ldap_uri = ldap://localhost
ldap_search_base = $LDAP_BASE_DN
ldap_default_bind_dn = $SSSD_BIND_DN
ldap_default_authtok_type = password
ldap_default_authtok = $SSSD_BIND_PASSWORD

ldap_user_search_base = ou=users,$LDAP_BASE_DN
ldap_user_object_class = posixAccount
ldap_user_name = uid
ldap_user_uid_number = uidNumber
ldap_user_gid_number = gidNumber
ldap_user_home_directory = homeDirectory
ldap_user_shell = loginShell
ldap_user_gecos = cn

ldap_group_search_base = ou=groups,$LDAP_BASE_DN
ldap_group_object_class = posixGroup
ldap_group_name = cn
ldap_group_gid_number = gidNumber
ldap_group_member = memberUid

enumerate = false
cache_credentials = true
EOF

chmod 600 /etc/sssd/sssd.conf
chown root:root /etc/sssd/sssd.conf

log_ok "sssd.conf ecrit."

# Etape 2 : Activer NSS pour SSSD
log_info "Activation de NSS pour SSSD..."

if ! grep -q "^passwd:.*sss" /etc/nsswitch.conf; then
    sed -i 's/^passwd:.*/& sss/' /etc/nsswitch.conf
fi
if ! grep -q "^group:.*sss" /etc/nsswitch.conf; then
    sed -i 's/^group:.*/& sss/' /etc/nsswitch.conf
fi

log_ok "NSS configure pour SSSD."

# Etape 3 : Activer PAM pour SSSD et mkhomedir
log_info "Activation de PAM pour SSSD..."
pam-auth-update --enable sssd --enable mkhomedir --force
log_ok "PAM configure."

# Etape 4 : Demarrer SSSD
log_info "Demarrage de SSSD..."
systemctl enable sssd >/dev/null 2>&1
systemctl restart sssd
sleep 3
check_service sssd

# Etape 5 : Verifier la resolution des utilisateurs LDAP
log_info "Verification de la resolution LDAP via SSSD..."

if ! getent passwd enseignant01 >/dev/null; then
    die "SSSD ne resout pas enseignant01. Verifier /etc/sssd/sssd.conf et les logs."
fi

if ! getent group enseignants >/dev/null; then
    die "SSSD ne resout pas le groupe enseignants."
fi

log_ok "Utilisateurs et groupes LDAP resolus."

# Etape 6 : Appliquer les permissions POSIX et ACL
log_info "Application des permissions POSIX et ACL..."

# cours : lecture pour apprenants, ecriture pour enseignants
chown root:enseignants "$SHARES_BASE/cours"
chmod 2775 "$SHARES_BASE/cours"
setfacl -R -m g:enseignants:rwx "$SHARES_BASE/cours"
setfacl -R -m g:apprenants:r-x "$SHARES_BASE/cours"
setfacl -R -d -m g:enseignants:rwx "$SHARES_BASE/cours"
setfacl -R -d -m g:apprenants:r-x "$SHARES_BASE/cours"

# tp : ecriture pour tous
chown root:enseignants "$SHARES_BASE/tp"
chmod 2775 "$SHARES_BASE/tp"
setfacl -R -m g:enseignants:rwx "$SHARES_BASE/tp"
setfacl -R -m g:apprenants:rwx "$SHARES_BASE/tp"
setfacl -R -d -m g:enseignants:rwx "$SHARES_BASE/tp"
setfacl -R -d -m g:apprenants:rwx "$SHARES_BASE/tp"

# public : lecture pour apprenants, ecriture pour enseignants
chown root:enseignants "$SHARES_BASE/public"
chmod 2775 "$SHARES_BASE/public"
setfacl -R -m g:enseignants:rwx "$SHARES_BASE/public"
setfacl -R -m g:apprenants:r-x "$SHARES_BASE/public"
setfacl -R -m o::r-x "$SHARES_BASE/public"
setfacl -R -d -m g:enseignants:rwx "$SHARES_BASE/public"
setfacl -R -d -m g:apprenants:r-x "$SHARES_BASE/public"
setfacl -R -d -m o::r-x "$SHARES_BASE/public"

log_ok "Permissions appliquees."

# Etape 7 : Redemarrer Samba
log_info "Redemarrage de Samba..."
systemctl restart smbd nmbd
sleep 2
check_service smbd
check_service nmbd

log_ok "Integration terminee."
