#!/usr/bin/env bash
# Configure OpenLDAP : domaine, schema Samba, structure DIT, groupes, utilisateurs.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export PROJECT_ROOT
source "${SCRIPT_DIR}/lib.sh"

require_root
load_config

LDIF_DIR="/root/ldap-ldifs"
mkdir -p "$LDIF_DIR"

# Etape 1 : Reconfigurer slapd
log_info "Configuration du domaine LDAP et du mot de passe admin..."

if slapcat -b "$LDAP_BASE_DN" >/dev/null 2>&1; then
    log_ok "La base $LDAP_BASE_DN existe deja, configuration ignoree."
else
    debconf-set-selections <<EOF
slapd slapd/domain string $LDAP_DOMAIN
slapd shared/organization string Etablissement
slapd slapd/password1 password $LDAP_ADMIN_PASSWORD
slapd slapd/password2 password $LDAP_ADMIN_PASSWORD
slapd slapd/backend select MDB
slapd slapd/purge_database boolean false
slapd slapd/allow_ldap_v2 boolean false
slapd slapd/move_old_database boolean true
EOF
    DEBIAN_FRONTEND=noninteractive dpkg-reconfigure -f noninteractive slapd
    log_ok "slapd configure avec le domaine $LDAP_DOMAIN."
fi

check_service slapd

# Etape 2 : Charger le schema Samba
log_info "Chargement du schema Samba dans OpenLDAP..."

if ldapsearch -Y EXTERNAL -H ldapi:/// -b "cn=schema,cn=config" -s base "(objectClass=*)" olcAttributeTypes 2>/dev/null | grep -q "sambaNTPassword"; then
    log_ok "Schema Samba deja charge."
else
    ldapadd -Y EXTERNAL -H ldapi:/// -f /usr/share/doc/samba/examples/LDAP/samba.ldif
    log_ok "Schema Samba charge."
fi

# Etape 3 : Generer le SID du domaine Samba
log_info "Generation du SID du domaine Samba..."

if [[ -f /var/lib/samba/private/secrets.tdb ]]; then
    SAMBA_DOMAIN_SID=$(net getlocalsid | awk '{print $NF}')
    log_ok "SID du domaine existant : $SAMBA_DOMAIN_SID"
else
    log_info "Premier demarrage de Samba pour generer le SID..."
    systemctl start smbd nmbd
    sleep 3
    SAMBA_DOMAIN_SID=$(net getlocalsid | awk '{print $NF}')
    systemctl stop smbd nmbd
    log_ok "SID du domaine genere : $SAMBA_DOMAIN_SID"
fi

mkdir -p /etc/projet-soutenance
echo "SAMBA_DOMAIN_SID=\"$SAMBA_DOMAIN_SID\"" > /etc/projet-soutenance/samba-sid.env

# Etape 4 : Creer la structure DIT
log_info "Creation de la structure DIT..."

cat > "$LDIF_DIR/01-structure.ldif" <<EOF
dn: ou=users,$LDAP_BASE_DN
objectClass: organizationalUnit
ou: users

dn: ou=groups,$LDAP_BASE_DN
objectClass: organizationalUnit
ou: groups
EOF

if ldapsearch -x -H ldap://localhost -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -b "ou=users,$LDAP_BASE_DN" "(objectClass=*)" dn 2>/dev/null | grep -q "^dn:"; then
    log_ok "Structure DIT deja presente."
else
    ldapadd -x -H ldap://localhost -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -f "$LDIF_DIR/01-structure.ldif"
fi

# Etape 5 : Creer les groupes POSIX
log_info "Creation des groupes POSIX..."

cat > "$LDIF_DIR/02-groupes.ldif" <<EOF
dn: cn=enseignants,ou=groups,$LDAP_BASE_DN
objectClass: posixGroup
cn: enseignants
gidNumber: $ENSEIGNANTS_GID

dn: cn=apprenants,ou=groups,$LDAP_BASE_DN
objectClass: posixGroup
cn: apprenants
gidNumber: $APPRENANTS_GID
EOF

if ldapsearch -x -H ldap://localhost -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -b "cn=enseignants,ou=groups,$LDAP_BASE_DN" "(objectClass=*)" dn 2>/dev/null | grep -q "^dn:"; then
    log_ok "Groupes POSIX deja presents."
else
    ldapadd -x -H ldap://localhost -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -f "$LDIF_DIR/02-groupes.ldif"
fi

# Etape 6 : Creer les utilisateurs POSIX
log_info "Creation des utilisateurs POSIX..."

SSHA_HASH=$(slappasswd -h '{SSHA}' -s "$USER_PASSWORD")

cat > "$LDIF_DIR/03-utilisateurs.ldif" <<EOF
dn: uid=enseignant01,ou=users,$LDAP_BASE_DN
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
uid: enseignant01
cn: Enseignant Un
sn: Un
givenName: Enseignant
displayName: Enseignant Un
mail: enseignant01@$LDAP_DOMAIN
uidNumber: $ENSEIGNANT01_UID
gidNumber: $ENSEIGNANTS_GID
homeDirectory: /home/enseignant01
loginShell: /bin/bash
userPassword: $SSHA_HASH

dn: uid=enseignant02,ou=users,$LDAP_BASE_DN
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
uid: enseignant02
cn: Enseignant Deux
sn: Deux
givenName: Enseignant
displayName: Enseignant Deux
mail: enseignant02@$LDAP_DOMAIN
uidNumber: $ENSEIGNANT02_UID
gidNumber: $ENSEIGNANTS_GID
homeDirectory: /home/enseignant02
loginShell: /bin/bash
userPassword: $SSHA_HASH

dn: uid=apprenant01,ou=users,$LDAP_BASE_DN
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
uid: apprenant01
cn: Apprenant Un
sn: Un
givenName: Apprenant
displayName: Apprenant Un
mail: apprenant01@$LDAP_DOMAIN
uidNumber: $APPRENANT01_UID
gidNumber: $APPRENANTS_GID
homeDirectory: /home/apprenant01
loginShell: /bin/bash
userPassword: $SSHA_HASH

dn: uid=apprenant02,ou=users,$LDAP_BASE_DN
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
uid: apprenant02
cn: Apprenant Deux
sn: Deux
givenName: Apprenant
displayName: Apprenant Deux
mail: apprenant02@$LDAP_DOMAIN
uidNumber: $APPRENANT02_UID
gidNumber: $APPRENANTS_GID
homeDirectory: /home/apprenant02
loginShell: /bin/bash
userPassword: $SSHA_HASH
EOF

if ldapsearch -x -H ldap://localhost -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -b "uid=enseignant01,ou=users,$LDAP_BASE_DN" "(objectClass=*)" dn 2>/dev/null | grep -q "^dn:"; then
    log_ok "Utilisateurs POSIX deja presents."
else
    ldapadd -x -H ldap://localhost -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -f "$LDIF_DIR/03-utilisateurs.ldif"
fi

# Etape 7 : Ajouter les membres aux groupes
log_info "Ajout des membres aux groupes..."

cat > "$LDIF_DIR/04-membres.ldif" <<EOF
dn: cn=enseignants,ou=groups,$LDAP_BASE_DN
changetype: modify
add: memberUid
memberUid: enseignant01
memberUid: enseignant02

dn: cn=apprenants,ou=groups,$LDAP_BASE_DN
changetype: modify
add: memberUid
memberUid: apprenant01
memberUid: apprenant02
EOF

if ldapsearch -x -H ldap://localhost -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -b "cn=enseignants,ou=groups,$LDAP_BASE_DN" "(memberUid=enseignant01)" memberUid 2>/dev/null | grep -q "memberUid: enseignant01"; then
    log_ok "Membres deja ajoutes."
else
    ldapmodify -x -H ldap://localhost -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -f "$LDIF_DIR/04-membres.ldif"
fi

# Etape 8 : Ajouter les attributs Samba aux utilisateurs
log_info "Ajout des attributs Samba aux utilisateurs..."

NTLM_HASH=$(printf '%s' "$USER_PASSWORD" | iconv -t UTF-16LE | openssl dgst -md4 -provider legacy | awk '{print toupper($NF)}')
TIMESTAMP=$(date +%s)

cat > "$LDIF_DIR/06-samba-users.ldif" <<EOF
dn: uid=enseignant01,ou=users,$LDAP_BASE_DN
changetype: modify
add: objectClass
objectClass: sambaSAMAccount
-
add: sambaSID
sambaSID: $SAMBA_DOMAIN_SID-$ENSEIGNANT01_UID
-
add: sambaNTPassword
sambaNTPassword: $NTLM_HASH
-
add: sambaAcctFlags
sambaAcctFlags: [U]
-
add: sambaPwdLastSet
sambaPwdLastSet: $TIMESTAMP

dn: uid=enseignant02,ou=users,$LDAP_BASE_DN
changetype: modify
add: objectClass
objectClass: sambaSAMAccount
-
add: sambaSID
sambaSID: $SAMBA_DOMAIN_SID-$ENSEIGNANT02_UID
-
add: sambaNTPassword
sambaNTPassword: $NTLM_HASH
-
add: sambaAcctFlags
sambaAcctFlags: [U]
-
add: sambaPwdLastSet
sambaPwdLastSet: $TIMESTAMP

dn: uid=apprenant01,ou=users,$LDAP_BASE_DN
changetype: modify
add: objectClass
objectClass: sambaSAMAccount
-
add: sambaSID
sambaSID: $SAMBA_DOMAIN_SID-$APPRENANT01_UID
-
add: sambaNTPassword
sambaNTPassword: $NTLM_HASH
-
add: sambaAcctFlags
sambaAcctFlags: [U]
-
add: sambaPwdLastSet
sambaPwdLastSet: $TIMESTAMP

dn: uid=apprenant02,ou=users,$LDAP_BASE_DN
changetype: modify
add: objectClass
objectClass: sambaSAMAccount
-
add: sambaSID
sambaSID: $SAMBA_DOMAIN_SID-$APPRENANT02_UID
-
add: sambaNTPassword
sambaNTPassword: $NTLM_HASH
-
add: sambaAcctFlags
sambaAcctFlags: [U]
-
add: sambaPwdLastSet
sambaPwdLastSet: $TIMESTAMP
EOF

if ldapsearch -x -H ldap://localhost -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -b "uid=enseignant01,ou=users,$LDAP_BASE_DN" "(objectClass=sambaSAMAccount)" dn 2>/dev/null | grep -q "^dn:"; then
    log_ok "Attributs Samba deja presents sur les utilisateurs."
else
    ldapmodify -x -H ldap://localhost -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -f "$LDIF_DIR/06-samba-users.ldif"
fi

# Etape 9 : Ajouter les attributs Samba aux groupes
log_info "Ajout des attributs Samba aux groupes..."

cat > "$LDIF_DIR/07-samba-groups.ldif" <<EOF
dn: cn=enseignants,ou=groups,$LDAP_BASE_DN
changetype: modify
add: objectClass
objectClass: sambaGroupMapping
-
add: sambaSID
sambaSID: $SAMBA_DOMAIN_SID-$ENSEIGNANTS_GID
-
add: sambaGroupType
sambaGroupType: 2
-
add: displayName
displayName: Enseignants

dn: cn=apprenants,ou=groups,$LDAP_BASE_DN
changetype: modify
add: objectClass
objectClass: sambaGroupMapping
-
add: sambaSID
sambaSID: $SAMBA_DOMAIN_SID-$APPRENANTS_GID
-
add: sambaGroupType
sambaGroupType: 2
-
add: displayName
displayName: Apprenants
EOF

if ldapsearch -x -H ldap://localhost -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -b "cn=enseignants,ou=groups,$LDAP_BASE_DN" "(objectClass=sambaGroupMapping)" dn 2>/dev/null | grep -q "^dn:"; then
    log_ok "Attributs Samba deja presents sur les groupes."
else
    ldapmodify -x -H ldap://localhost -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -f "$LDIF_DIR/07-samba-groups.ldif"
fi

# Etape 10 : Creer l'entree sambaDomainName
log_info "Creation de l'entree sambaDomainName..."

cat > "$LDIF_DIR/08-samba-domain.ldif" <<EOF
dn: sambaDomainName=$SAMBA_WORKGROUP,$LDAP_BASE_DN
objectClass: sambaDomain
sambaDomainName: $SAMBA_WORKGROUP
sambaSID: $SAMBA_DOMAIN_SID
sambaAlgorithmicRidBase: 1000
EOF

if ldapsearch -x -H ldap://localhost -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -b "sambaDomainName=$SAMBA_WORKGROUP,$LDAP_BASE_DN" "(objectClass=*)" dn 2>/dev/null | grep -q "^dn:"; then
    log_ok "Entree sambaDomainName deja presente."
else
    ldapadd -x -H ldap://localhost -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -f "$LDIF_DIR/08-samba-domain.ldif"
fi

# Etape 11 : Creer les comptes de service
log_info "Creation des comptes de service LDAP..."

SERVICES_OU="ou=services,$LDAP_BASE_DN"
SERVICE_ENV="/etc/projet-soutenance/service-accounts.env"

# Generer ou recuperer les mots de passe de service
generate_or_get_password() {
    local var_name="$1"
    local file="$2"
    if [[ -f "$file" ]] && grep -q "^${var_name}=" "$file"; then
        # shellcheck disable=SC1090
        grep "^${var_name}=" "$file" | cut -d= -f2- | tr -d '"'
    else
        openssl rand -base64 24 | tr -d '/+=' | head -c 32
    fi
}

mkdir -p /etc/projet-soutenance
chmod 700 /etc/projet-soutenance

if [[ ! -f "$SERVICE_ENV" ]]; then
    SSSD_BIND_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=' | head -c 32)
    SAMBA_BIND_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=' | head -c 32)
    RADIUS_BIND_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=' | head -c 32)

    cat > "$SERVICE_ENV" <<EOF
# Comptes de service LDAP
# Genere automatiquement le $(date)
SSSD_BIND_DN="cn=sssd,ou=services,$LDAP_BASE_DN"
SSSD_BIND_PASSWORD="$SSSD_BIND_PASSWORD"
SAMBA_BIND_DN="cn=samba,ou=services,$LDAP_BASE_DN"
SAMBA_BIND_PASSWORD="$SAMBA_BIND_PASSWORD"
RADIUS_BIND_DN="cn=radius,ou=services,$LDAP_BASE_DN"
RADIUS_BIND_PASSWORD="$RADIUS_BIND_PASSWORD"
EOF
    chmod 600 "$SERVICE_ENV"
    chown root:root "$SERVICE_ENV"
    log_ok "Fichier des comptes de service cree : $SERVICE_ENV"
else
    log_ok "Fichier des comptes de service deja present."
fi

# shellcheck disable=SC1090
source "$SERVICE_ENV"

# Creer l'OU services et les trois comptes si absents
for account in sssd samba radius; do
    account_dn="cn=$account,ou=services,$LDAP_BASE_DN"
    if ldapsearch -x -H ldap://localhost -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" \
        -b "$account_dn" -s base "(objectClass=*)" dn 2>/dev/null | grep -q "^dn:"; then
        log_ok "Compte de service $account deja present."
        continue
    fi

    case "$account" in
        sssd)   password="$SSSD_BIND_PASSWORD" ;;
        samba)  password="$SAMBA_BIND_PASSWORD" ;;
        radius) password="$RADIUS_BIND_PASSWORD" ;;
    esac

    HASH=$(slappasswd -h '{SSHA}' -s "$password")

    cat > "$LDIF_DIR/09-service-$account.ldif" <<EOF
dn: ou=services,$LDAP_BASE_DN
objectClass: organizationalUnit
ou: services

dn: $account_dn
objectClass: simpleSecurityObject
objectClass: organizationalRole
cn: $account
description: Compte de service pour $account
userPassword: $HASH
EOF

    if ldapadd -x -H ldap://localhost -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" \
        -f "$LDIF_DIR/09-service-$account.ldif" >/dev/null 2>&1; then
        log_ok "Compte de service $account cree."
    else
        log_error "Echec de creation du compte de service $account."
    fi
done

# Etape 12 : Appliquer les ACL sur les attributs sensibles
log_info "Application des ACL restrictives sur les attributs sensibles..."

ACL_LDIF=$(mktemp)
cat > "$ACL_LDIF" <<EOF
dn: olcDatabase={1}mdb,cn=config
changetype: modify
replace: olcAccess
olcAccess: {0}to attrs=userPassword,sambaLMPassword,sambaNTPassword
  by self write
  by anonymous auth
  by dn.exact="$LDAP_ADMIN_DN" write
  by dn.exact="$SAMBA_BIND_DN" write
  by dn.exact="$SSSD_BIND_DN" read
  by dn.exact="$RADIUS_BIND_DN" read
  by * none
olcAccess: {1}to *
  by dn.exact="$LDAP_ADMIN_DN" write
  by dn.exact="$SAMBA_BIND_DN" read
  by dn.exact="$SSSD_BIND_DN" read
  by dn.exact="$RADIUS_BIND_DN" read
  by self read
  by users read
  by * none
EOF

if ldapmodify -Y EXTERNAL -H ldapi:/// -f "$ACL_LDIF" >/dev/null 2>&1; then
    log_ok "ACL restrictives appliquees."
else
    log_error "Echec de l'application des ACL."
    cat "$ACL_LDIF"
fi
rm -f "$ACL_LDIF"

# Verification immediate : SSSD doit toujours resoudre les utilisateurs
if getent passwd enseignant01 >/dev/null 2>&1; then
    log_ok "SSSD resout toujours les utilisateurs apres ACL."
else
    log_error "SSSD ne resout plus les utilisateurs. Verifier les ACL."
fi

log_ok "OpenLDAP configure."
