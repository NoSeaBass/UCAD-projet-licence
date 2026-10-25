#!/usr/bin/env bash
# Configure Samba : smb.conf, mot de passe LDAP, repertoires de partages.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export PROJECT_ROOT
source "${SCRIPT_DIR}/lib.sh"

require_root
load_config

# shellcheck disable=SC1091
source /etc/projet-soutenance/service-accounts.env

# Etape 1 : Recuperer le SID du domaine
SID_FILE="/etc/projet-soutenance/samba-sid.env"
if [[ ! -f "$SID_FILE" ]]; then
    die "Fichier $SID_FILE introuvable. Executer openldap.sh d'abord."
fi
source "$SID_FILE"

if [[ -z "${SAMBA_DOMAIN_SID:-}" ]]; then
    die "SAMBA_DOMAIN_SID non defini dans $SID_FILE."
fi

log_info "SID du domaine : $SAMBA_DOMAIN_SID"

# Etape 2 : Ecrire smb.conf
log_info "Ecriture de /etc/samba/smb.conf..."

if [[ -f /etc/samba/smb.conf ]]; then
    cp /etc/samba/smb.conf /etc/samba/smb.conf.bak.$(date +%s)
fi

cat > /etc/samba/smb.conf <<EOF
[global]
   workgroup = $SAMBA_WORKGROUP
   server string = Serveur Pedagogique
   netbios name = $SAMBA_NETBIOS_NAME
   security = user

   passdb backend = ldapsam:ldap://localhost
   ldap admin dn = $SAMBA_BIND_DN
   ldap suffix = $LDAP_BASE_DN
   ldap user suffix = ou=users
   ldap group suffix = ou=groups
   ldap machine suffix = ou=users
   ldap delete dn = no
   ldap ssl = off

   log file = /var/log/samba/log.%m
   max log size = 1000
   logging = file

   map to guest = never
   dns proxy = no

   idmap config * : backend = tdb
   idmap config * : range = 3000-7999

   load printers = no
   printing = bsd
   printcap name = /dev/null
   disable spoolss = yes

[cours]
   comment = Cours (lecture seule pour apprenants)
   path = $SHARES_BASE/cours
   browseable = yes
   read only = no
   guest ok = no
   valid users = @enseignants, @apprenants
   write list = @enseignants
   create mask = 0664
   directory mask = 2775

[tp]
   comment = Travaux pratiques (lecture-ecriture pour tous)
   path = $SHARES_BASE/tp
   browseable = yes
   read only = no
   guest ok = no
   valid users = @enseignants, @apprenants
   write list = @enseignants, @apprenants
   create mask = 0664
   directory mask = 2775

[public]
   comment = Espace public (lecture pour tous)
   path = $SHARES_BASE/public
   browseable = yes
   read only = no
   guest ok = no
   valid users = @enseignants, @apprenants
   write list = @enseignants
   create mask = 0664
   directory mask = 2775

[homes]
   comment = Repertoire personnel
   browseable = no
   read only = no
   guest ok = no
   valid users = %S
   create mask = 0600
   directory mask = 0700
EOF

log_ok "smb.conf ecrit."

# Etape 3 : Verifier la syntaxe de smb.conf
log_info "Verification de smb.conf..."
testparm -s >/dev/null
log_ok "smb.conf valide."

# Etape 4 : Stocker le mot de passe LDAP admin dans secrets.tdb
log_info "Enregistrement du mot de passe LDAP admin dans Samba..."

TMP_PW=$(mktemp)
chmod 600 "$TMP_PW"
printf '%s\n%s\n' "$SAMBA_BIND_PASSWORD" "$SAMBA_BIND_PASSWORD" > "$TMP_PW"

if ! smbpasswd -W -s < "$TMP_PW"; then
    rm -f "$TMP_PW"
    die "Echec de l'enregistrement du mot de passe LDAP admin."
fi

rm -f "$TMP_PW"
log_ok "Mot de passe LDAP admin enregistre."

# Etape 5 : Creer les repertoires de partages
log_info "Creation des repertoires de partages..."

mkdir -p "$SHARES_BASE"/{cours,tp,public}
chmod 2775 "$SHARES_BASE"/{cours,tp,public}
log_ok "Repertoires crees sous $SHARES_BASE (permissions appliquees dans integration.sh)."

# Etape 6 : Demarrer Samba
log_info "Demarrage de Samba..."

systemctl enable smbd nmbd >/dev/null 2>&1
systemctl restart smbd nmbd
sleep 2

check_service smbd
check_service nmbd

log_ok "Samba configure."
