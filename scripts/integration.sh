#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export PROJECT_ROOT
source "${SCRIPT_DIR}/lib.sh"

require_root
load_config

if [[ -f /etc/projet-soutenance/service-accounts.env ]]; then
    source /etc/projet-soutenance/service-accounts.env
else
    die "Fichier /etc/projet-soutenance/service-accounts.env introuvable. Executer openldap.sh d'abord."
fi

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
ldap_uri = ldap://127.0.0.1
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

log_info "Activation de NSS pour SSSD..."

if ! grep -q "^passwd:.*sss" /etc/nsswitch.conf; then
    sed -i 's/^passwd:.*/& sss/' /etc/nsswitch.conf
fi
if ! grep -q "^group:.*sss" /etc/nsswitch.conf; then
    sed -i 's/^group:.*/& sss/' /etc/nsswitch.conf
fi

log_ok "NSS configure pour SSSD."

log_info "Activation de PAM pour SSSD..."
pam-auth-update --enable sssd --enable mkhomedir --force
log_ok "PAM configure."

log_info "Demarrage de SSSD..."
systemctl disable --now sssd-nss.socket sssd-pam.socket sssd-pam-priv.socket >/dev/null 2>&1 || true
systemctl enable sssd >/dev/null 2>&1
systemctl restart sssd
sleep 3
check_service sssd

log_info "Verification de la resolution LDAP via SSSD..."

if ! getent passwd enseignant01 >/dev/null; then
    die "SSSD ne resout pas enseignant01. Verifier /etc/sssd/sssd.conf et les logs."
fi

if ! getent group enseignants >/dev/null; then
    die "SSSD ne resout pas le groupe enseignants."
fi

log_ok "Utilisateurs et groupes LDAP resolus."

log_info "Application des permissions POSIX et ACL..."

chown root:enseignants "$SHARES_BASE/cours"
chmod 2775 "$SHARES_BASE/cours"
setfacl -R -m g:enseignants:rwx "$SHARES_BASE/cours"
setfacl -R -m g:apprenants:r-x "$SHARES_BASE/cours"
setfacl -R -d -m g:enseignants:rwx "$SHARES_BASE/cours"
setfacl -R -d -m g:apprenants:r-x "$SHARES_BASE/cours"

chown root:enseignants "$SHARES_BASE/tp"
chmod 2775 "$SHARES_BASE/tp"
setfacl -R -m g:enseignants:rwx "$SHARES_BASE/tp"
setfacl -R -m g:apprenants:rwx "$SHARES_BASE/tp"
setfacl -R -d -m g:enseignants:rwx "$SHARES_BASE/tp"
setfacl -R -d -m g:apprenants:rwx "$SHARES_BASE/tp"

chown root:enseignants "$SHARES_BASE/public"
chmod 2775 "$SHARES_BASE/public"
setfacl -R -m g:enseignants:rwx "$SHARES_BASE/public"
setfacl -R -m g:apprenants:r-x "$SHARES_BASE/public"
setfacl -R -m o::r-x "$SHARES_BASE/public"
setfacl -R -d -m g:enseignants:rwx "$SHARES_BASE/public"
setfacl -R -d -m g:apprenants:r-x "$SHARES_BASE/public"
setfacl -R -d -m o::r-x "$SHARES_BASE/public"

log_ok "Permissions appliquees."

log_info "Redemarrage de Samba..."
systemctl restart smbd nmbd
sleep 2
check_service smbd
check_service nmbd

log_ok "Integration terminee."
