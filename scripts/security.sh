#!/usr/bin/env bash
# Applique les mesures de securite : UFW, SSH, permissions, TLS.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
FR_DIR="/etc/freeradius/3.0"
export PROJECT_ROOT
source "${SCRIPT_DIR}/lib.sh"

# Etape 0 : Creer les repertoires necessaires
mkdir -p /run/sshd
chmod 0755 /run/sshd

mkdir -p /etc/projet-soutenance/tls
chmod 700 /etc/projet-soutenance/tls

mkdir -p /etc/ldap

mkdir -p /etc/freeradius/3.0/certs
chown freerad:freerad /etc/freeradius/3.0/certs 2>/dev/null || true

require_root
load_config

# Etape 1 : Pare-feu UFW
log_info "Configuration du pare-feu UFW..."

if ! command -v ufw >/dev/null 2>&1; then
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq ufw
fi

ufw --force default deny incoming >/dev/null
ufw --force default allow outgoing >/dev/null

ufw allow 22/tcp >/dev/null
ufw allow 445/tcp >/dev/null
ufw allow 139/tcp >/dev/null

SUBNET=$(echo "$IP_ADDRESS" | awk -F. '{print $1"."$2"."$3".0/24"}')
ufw allow from "$SUBNET" to any port 389 proto tcp >/dev/null
ufw allow from "$SUBNET" to any port 636 proto tcp >/dev/null

ufw allow 1812/udp >/dev/null
ufw allow 1813/udp >/dev/null

ufw --force enable >/dev/null
log_ok "UFW active avec les regles de base."

# Etape 2 : Durcissement SSH
log_info "Durcissement de la configuration SSH..."

SSHD_CONF="/etc/ssh/sshd_config"
if [[ ! -f "${SSHD_CONF}.orig" ]]; then
    cp "$SSHD_CONF" "${SSHD_CONF}.orig"
fi

set_sshd_option() {
    local key="$1"
    local value="$2"
    if grep -qE "^\s*#?\s*${key}\s+" "$SSHD_CONF"; then
        sed -i -E "s|^\s*#?\s*${key}\s+.*|${key} ${value}|" "$SSHD_CONF"
    else
        echo "${key} ${value}" >> "$SSHD_CONF"
    fi
}

set_sshd_option "PermitRootLogin" "no"
set_sshd_option "PasswordAuthentication" "yes"
set_sshd_option "PubkeyAuthentication" "yes"
set_sshd_option "X11Forwarding" "no"
set_sshd_option "MaxAuthTries" "3"
set_sshd_option "LoginGraceTime" "30"

# Verifier la syntaxe (le repertoire /run/sshd existe maintenant)
if ! sshd -t; then
    log_error "Configuration SSH invalide. Restauration depuis ${SSHD_CONF}.orig"
    cp "${SSHD_CONF}.orig" "$SSHD_CONF"
    exit 1
fi

systemctl restart ssh
sleep 1
check_service ssh
log_ok "SSH durci."

# Etape 3 : Autorite de certification interne
log_info "Verification de l'autorite de certification..."

CA_DIR="/etc/projet-soutenance/tls"
CA_KEY="$CA_DIR/ca.key"
CA_CERT="$CA_DIR/ca.crt"
EXT_FILE="$CA_DIR/ext.cnf"

if [[ ! -f "$CA_KEY" ]] || [[ ! -f "$CA_CERT" ]]; then
    log_info "Generation de la CA interne (valable 10 ans)..."
    openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
        -keyout "$CA_KEY" -out "$CA_CERT" \
        -subj "/O=Projet Soutenance/CN=Projet-Soutenance-CA" \
        >/dev/null 2>&1
    chmod 600 "$CA_KEY"
    chmod 644 "$CA_CERT"
    log_ok "CA generee : $CA_CERT"
else
    log_ok "CA deja presente."
fi

# Ajouter la CA au magasin de confiance du systeme
cp "$CA_CERT" /usr/local/share/ca-certificates/projet-soutenance-ca.crt
update-ca-certificates >/dev/null 2>&1

# Configurer ldap.conf pour la verification des certificats
cat > /etc/ldap/ldap.conf <<EOF
TLS_CACERT /etc/ldap/ca.crt
EOF

log_ok "CA ajoutee au magasin de confiance."

# Fichier d'extensions commun (subjectAltName)
cat > "$EXT_FILE" <<EOF
subjectAltName=DNS:$HOSTNAME,DNS:$HOSTNAME.$LDAP_DOMAIN,DNS:localhost,IP:127.0.0.1
EOF
chmod 644 "$EXT_FILE"

# Etape 4 : Certificat serveur pour OpenLDAP
log_info "Generation du certificat serveur pour OpenLDAP..."

LDAP_KEY="$CA_DIR/ldap.key"
LDAP_CERT="$CA_DIR/ldap.crt"
LDAP_CSR="$CA_DIR/ldap.csr"

if [[ ! -f "$LDAP_KEY" ]] || [[ ! -f "$LDAP_CERT" ]]; then
    openssl req -newkey rsa:2048 -nodes \
        -keyout "$LDAP_KEY" -out "$LDAP_CSR" \
        -subj "/O=Projet Soutenance/CN=$HOSTNAME" \
        >/dev/null 2>&1

    openssl x509 -req -in "$LDAP_CSR" -CA "$CA_CERT" -CAkey "$CA_KEY" \
        -CAcreateserial -days 825 -sha256 -out "$LDAP_CERT" \
        -extfile "$EXT_FILE" >/dev/null 2>&1

    chmod 600 "$LDAP_KEY"
    chmod 644 "$LDAP_CERT"
    log_ok "Certificat LDAP genere."
else
    log_ok "Certificat LDAP deja present."
fi

cp "$LDAP_CERT" /etc/ldap/ldap.crt
cp "$LDAP_KEY"  /etc/ldap/ldap.key
cp "$CA_CERT"   /etc/ldap/ca.crt
chown openldap:openldap /etc/ldap/ldap.key /etc/ldap/ldap.crt /etc/ldap/ca.crt
chmod 600 /etc/ldap/ldap.key
chmod 644 /etc/ldap/ldap.crt /etc/ldap/ca.crt

# Etape 5 : Activation de LDAPS dans slapd
log_info "Activation de LDAPS dans slapd..."

TLS_LDIF=$(mktemp)
cat > "$TLS_LDIF" <<EOF
dn: cn=config
changetype: modify
replace: olcTLSCACertificateFile
olcTLSCACertificateFile: /etc/ldap/ca.crt
-
replace: olcTLSCertificateFile
olcTLSCertificateFile: /etc/ldap/ldap.crt
-
replace: olcTLSCertificateKeyFile
olcTLSCertificateKeyFile: /etc/ldap/ldap.key
EOF

if ! ldapmodify -Y EXTERNAL -H ldapi:/// -f "$TLS_LDIF" >/dev/null 2>&1; then
    log_error "Impossible de configurer TLS dans slapd."
    rm -f "$TLS_LDIF"
    exit 1
fi
rm -f "$TLS_LDIF"

SLAPD_DEFAULT="/etc/default/slapd"
backup_file "$SLAPD_DEFAULT"
if ! grep -q 'ldaps:///' "$SLAPD_DEFAULT"; then
    sed -i 's|^SLAPD_SERVICES=.*|# SLAPD_SERVICES=disabled|' "$SLAPD_DEFAULT"
    sed -i 's|^# SLAPD_SERVICES=.*|# SLAPD_SERVICES=disabled|' "$SLAPD_DEFAULT"
    echo 'SLAPD_SERVICES="ldap:/// ldapi:/// ldaps:///"' >> "$SLAPD_DEFAULT"
fi
log_ok "SLAPD_SERVICES mis a jour pour LDAPS."

systemctl restart slapd
sleep 2
check_service slapd

if ss -tlnp | grep -q ":636"; then
    log_ok "LDAPS ecoute sur le port 636."
else
    log_error "LDAPS n'ecoute pas sur le port 636."
fi

# Etape 6 : Mise a jour de SSSD pour LDAPS
log_info "Mise a jour de SSSD pour utiliser LDAPS..."

if [[ -f /etc/sssd/sssd.conf ]]; then
    backup_file /etc/sssd/sssd.conf
    sed -i 's|^ldap_uri = ldap://.*|ldap_uri = ldaps://localhost|' /etc/sssd/sssd.conf

    if ! grep -q "^ldap_tls_cacert" /etc/sssd/sssd.conf; then
        sed -i '/^\[domain\//a ldap_tls_cacert = /etc/ldap/ca.crt\nldap_tls_reqcert = demand' /etc/sssd/sssd.conf
    fi

    chmod 600 /etc/sssd/sssd.conf
    chown root:root /etc/sssd/sssd.conf

    systemctl restart sssd
    sleep 3

    if systemctl is-active --quiet sssd; then
        log_ok "SSSD redemarre avec LDAPS."
    else
        log_error "SSSD n'a pas redemarre."
        journalctl -u sssd --no-pager | tail -10
        exit 1
    fi

    if getent passwd enseignant01 >/dev/null 2>&1; then
        log_ok "SSSD resout toujours les utilisateurs via LDAPS."
    else
        log_error "SSSD ne resout plus les utilisateurs."
        exit 1
    fi
fi

# Desactiver les sockets systemd en conflit avec SSSD
systemctl disable sssd-nss.socket 2>/dev/null || true
systemctl disable sssd-pam.socket 2>/dev/null || true
systemctl disable sssd-pam-priv.socket 2>/dev/null || true

# Ajouter un drop-in pour attendre le reseau
mkdir -p /etc/systemd/system/sssd.service.d
cat > /etc/systemd/system/sssd.service.d/override.conf <<EOF
[Unit]
After=network-online.target
Wants=network-online.target
EOF

systemctl daemon-reload
log_ok "SSSD : sockets desactives, drop-in reseau ajoute."

# Etape 7 : Certificat pour FreeRADIUS
log_info "Generation du certificat pour FreeRADIUS..."

# Configurer FreeRADIUS EAP pour utiliser le certificat
EAP_CONF="$FR_DIR/mods-available/eap"
if [[ -f "$EAP_CONF" ]]; then
    backup_file "$EAP_CONF"

    # Remplacer les chemins de certificat
    sed -i 's|^\s*private_key_file = .*|    private_key_file = /etc/freeradius/3.0/certs/server.key|' "$EAP_CONF"
    sed -i 's|^\s*certificate_file = .*|    certificate_file = /etc/freeradius/3.0/certs/server.crt|' "$EAP_CONF"
    sed -i 's|^\s*ca_file = .*|    ca_file = /etc/freeradius/3.0/certs/ca.crt|' "$EAP_CONF"

    log_ok "Configuration EAP mise a jour."
fi

RADIUS_KEY="$CA_DIR/radius.key"
RADIUS_CERT="$CA_DIR/radius.crt"
RADIUS_CSR="$CA_DIR/radius.csr"

if [[ ! -f "$RADIUS_KEY" ]] || [[ ! -f "$RADIUS_CERT" ]]; then
    openssl req -newkey rsa:2048 -nodes \
        -keyout "$RADIUS_KEY" -out "$RADIUS_CSR" \
        -subj "/O=Projet Soutenance/CN=$HOSTNAME" \
        >/dev/null 2>&1

    openssl x509 -req -in "$RADIUS_CSR" -CA "$CA_CERT" -CAkey "$CA_KEY" \
        -CAcreateserial -days 825 -sha256 -out "$RADIUS_CERT" \
        -extfile "$EXT_FILE" >/dev/null 2>&1

    chmod 600 "$RADIUS_KEY"
    chmod 644 "$RADIUS_CERT"
    log_ok "Certificat FreeRADIUS genere."
else
    log_ok "Certificat FreeRADIUS deja present."
fi

cp "$RADIUS_KEY"  /etc/freeradius/3.0/certs/server.key
cp "$RADIUS_CERT" /etc/freeradius/3.0/certs/server.crt
cp "$CA_CERT"     /etc/freeradius/3.0/certs/ca.crt
chown freerad:freerad /etc/freeradius/3.0/certs/server.key \
                       /etc/freeradius/3.0/certs/server.crt \
                       /etc/freeradius/3.0/certs/ca.crt
chmod 600 /etc/freeradius/3.0/certs/server.key
chmod 644 /etc/freeradius/3.0/certs/server.crt /etc/freeradius/3.0/certs/ca.crt

# Etape 8 : Permissions des fichiers sensibles
log_info "Verification des permissions des fichiers sensibles..."

if [[ -f /etc/sssd/sssd.conf ]]; then
    chmod 600 /etc/sssd/sssd.conf
    chown root:root /etc/sssd/sssd.conf
    log_ok "/etc/sssd/sssd.conf en 600 root:root."
fi

if [[ -f /etc/samba/smb.conf ]]; then
    chmod 640 /etc/samba/smb.conf
    chown root:root /etc/samba/smb.conf
    log_ok "/etc/samba/smb.conf en 640 root:root."
fi

if [[ -d /etc/freeradius/3.0 ]]; then
    chown root:freerad /etc/freeradius/3.0/clients.conf 2>/dev/null || true
    chmod 640 /etc/freeradius/3.0/clients.conf 2>/dev/null || true
    chown root:freerad /etc/freeradius/3.0/mods-available/ldap 2>/dev/null || true
    chmod 640 /etc/freeradius/3.0/mods-available/ldap 2>/dev/null || true
    log_ok "Permissions FreeRADIUS ajustees."
fi

chmod 600 "$CA_KEY"

for share in "$SHARES_BASE"/*; do
    [[ -d "$share" ]] || continue
    chown root:enseignants "$share"
    chmod 2775 "$share"
done
log_ok "Permissions des partages verifiees."

if [[ -f /etc/projet-soutenance/service-accounts.env ]]; then
    chmod 600 /etc/projet-soutenance/service-accounts.env
    chown root:root /etc/projet-soutenance/service-accounts.env
    log_ok "/etc/projet-soutenance/service-accounts.env en 600 root:root."
fi

# Override systemd pour FreeRADIUS : demarrer apres slapd
log_info "Configuration de l'override systemd pour FreeRADIUS..."

mkdir -p /etc/systemd/system/freeradius.service.d
cat > /etc/systemd/system/freeradius.service.d/override.conf <<EOF
[Unit]
After=slapd.service
Wants=slapd.service
EOF

systemctl daemon-reload
log_ok "Override systemd FreeRADIUS applique."

# Etape 9 : Reactivation de FreeRADIUS
if ! systemctl is-active --quiet freeradius; then
    log_info "Demarrage de FreeRADIUS..."
    systemctl enable freeradius >/dev/null 2>&1 || true
    systemctl start freeradius 2>/dev/null || true
    sleep 2
    if systemctl is-active --quiet freeradius; then
        log_ok "FreeRADIUS actif."
    else
        log_error "FreeRADIUS reste inactif."
    fi
else
    log_info "Redemarrage de FreeRADIUS pour charger les certificats..."
    systemctl restart freeradius
    sleep 2
    if systemctl is-active --quiet freeradius; then
        log_ok "FreeRADIUS redemarre."
    else
        log_error "FreeRADIUS n'a pas redemarre."
    fi
fi

log_ok "Securite appliquee (UFW, SSH, TLS, permissions)."
