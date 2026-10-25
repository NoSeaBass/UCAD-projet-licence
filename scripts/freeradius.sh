#!/usr/bin/env bash
# Configure FreeRADIUS avec LDAP et authentification par email.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export PROJECT_ROOT
source "${SCRIPT_DIR}/lib.sh"

require_root
load_config

# shellcheck disable=SC1091
source /etc/projet-soutenance/service-accounts.env

FR_DIR="/etc/freeradius/3.0"

# Etape 0 : Arreter FreeRADIUS pendant la configuration
log_info "Arret de FreeRADIUS pendant la configuration..."
#systemctl stop freeradius 2>/dev/null || true
#systemctl disable freeradius 2>/dev/null || true

# Etape 1 : Activer le module LDAP
log_info "Activation du module LDAP..."

if [[ ! -L "$FR_DIR/mods-enabled/ldap" ]]; then
    ln -s "$FR_DIR/mods-available/ldap" "$FR_DIR/mods-enabled/ldap"
    log_ok "Module LDAP active."
else
    log_ok "Module LDAP deja active."
fi

# Etape 2 : Configurer le module LDAP
log_info "Configuration du module LDAP..."

LDAP_MOD="$FR_DIR/mods-available/ldap"

if [[ ! -f "$LDAP_MOD.orig" ]]; then
    cp "$LDAP_MOD" "$LDAP_MOD.orig"
fi

# server
sed -i "s|^\(\s*\)server = .*|\1server = 'localhost'|" "$LDAP_MOD"

# identity : remplacer ou decommenter
if grep -qE "^\s*identity\s*=" "$LDAP_MOD"; then
    sed -i "s|^\(\s*\)identity\s*=.*|\1identity = '$RADIUS_BIND_DN'|" "$LDAP_MOD"
else
    sed -i "s|^#\(\s*\)identity\s*=.*|\1identity = '$RADIUS_BIND_DN'|" "$LDAP_MOD"
fi

# password : remplacer ou decommenter
if grep -qE "^\s*password\s*=" "$LDAP_MOD"; then
    sed -i "s|^\(\s*\)password\s*=.*|\1password = $RADIUS_BIND_PASSWORD|" "$LDAP_MOD"
else
    sed -i "s|^#\(\s*\)password\s*=.*|\1password = $RADIUS_BIND_PASSWORD|" "$LDAP_MOD"
fi

# base_dn
sed -i "s|^\(\s*\)base_dn = .*|\1base_dn = '$LDAP_BASE_DN'|" "$LDAP_MOD"

# Filtrer les utilisateurs par mail au lieu de uid
sed -i 's|^\(\s*\)filter = "(uid=%{%{Stripped-User-Name}:-%{User-Name}})".*|\1filter = "(mail=%{%{Stripped-User-Name}:-%{User-Name}})"|' "$LDAP_MOD"

log_ok "Module LDAP configure."

# Etape 3 : Activer LDAP dans le site par defaut
log_info "Activation de LDAP dans le site par defaut..."

DEFAULT_SITE="$FR_DIR/sites-available/default"

if [[ ! -f "$DEFAULT_SITE.orig" ]]; then
    cp "$DEFAULT_SITE" "$DEFAULT_SITE.orig"
fi

awk '
    /^authorize \{/ { in_auth=1 }
    in_auth && /^\s*#\s*ldap\s*$/ { sub(/#\s*ldap/, "ldap"); in_auth=0 }
    { print }
' "$DEFAULT_SITE.orig" > "$DEFAULT_SITE"

awk '
    /^authenticate \{/ { in_auth=1 }
    in_auth && /^\s*#\s*Auth-Type LDAP \{/ { print "        Auth-Type LDAP {"; skip=1; next }
    skip && /^\s*#\s*ldap\s*$/ { print "                ldap"; next }
    skip && /^\s*#\s*\}/ { print "        }"; skip=0; in_auth=0; next }
    { print }
' "$DEFAULT_SITE" > "${DEFAULT_SITE}.new"
mv "${DEFAULT_SITE}.new" "$DEFAULT_SITE"

log_ok "Site par defaut configure."

# Etape 4 : Verifier le shared secret du client localhost
log_info "Verification du client localhost..."

CLIENTS_FILE="$FR_DIR/clients.conf"
if ! grep -q "secret = $RADIUS_SHARED_SECRET" "$CLIENTS_FILE"; then
    awk -v secret="$RADIUS_SHARED_SECRET" '
        /^client localhost \{/ { in_block=1 }
        in_block && /^\s*secret\s*=/ { sub(/secret\s*=.*/, "secret = " secret); in_block=0 }
        { print }
    ' "$CLIENTS_FILE" > "${CLIENTS_FILE}.new"
    mv "${CLIENTS_FILE}.new" "$CLIENTS_FILE"
    log_ok "Shared secret du client localhost mis a jour."
else
    log_ok "Shared secret deja configure."
fi

# Etape 5 : Ouvrir les ports RADIUS dans UFW
log_info "Ouverture des ports RADIUS dans UFW..."

if command -v ufw >/dev/null 2>&1; then
    ufw allow 1812/udp >/dev/null 2>&1 || true
    ufw allow 1813/udp >/dev/null 2>&1 || true
    log_ok "Ports RADIUS ouverts."
fi

# Etape 6 : Verifier la configuration
log_info "Verification de la configuration FreeRADIUS..."

if ! freeradius -C >/dev/null 2>&1; then
    log_error "Configuration FreeRADIUS invalide. Verifier $FR_DIR."
    freeradius -C 2>&1 | tail -20
    exit 1
fi

log_ok "Configuration FreeRADIUS valide."

# Etape 7 : Demarrer FreeRADIUS
log_info "Demarrage de FreeRADIUS..."

systemctl enable freeradius >/dev/null 2>&1
systemctl start freeradius
sleep 2

if systemctl is-active --quiet freeradius; then
    log_ok "FreeRADIUS actif."
else
    log_error "FreeRADIUS n'a pas demarre. Verification des logs :"
    journalctl -u freeradius --no-pager | tail -10
    exit 1
fi

# Etape 8 : Test d'authentification reussie
log_info "Test d'authentification RADIUS reussie..."

if radtest "enseignant01@$LDAP_DOMAIN" "$USER_PASSWORD" localhost 0 "$RADIUS_SHARED_SECRET" 2>/dev/null | grep -q "Access-Accept"; then
    log_ok "Authentification PAP par email reussie."
else
    log_error "Authentification PAP par email ECHOUE."
    exit 1
fi

# Etape 9 : Test d'authentification refusee
log_info "Test d'authentification RADIUS refusee (mauvais mot de passe)..."

sleep 6

REJECT_OUTPUT=$(radtest "enseignant01@$LDAP_DOMAIN" "mauvais_mot_de_passe" localhost 0 "$RADIUS_SHARED_SECRET" 2>&1 || true)

if echo "$REJECT_OUTPUT" | grep -q "Access-Reject"; then
    log_ok "Rejet d'authentification correctement applique."
else
    log_error "Le rejet d'authentification n'a pas fonctionne."
    echo "$REJECT_OUTPUT"
    exit 1
fi

log_ok "FreeRADIUS configure."
