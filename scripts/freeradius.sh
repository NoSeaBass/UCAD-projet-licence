#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export PROJECT_ROOT
source "${SCRIPT_DIR}/lib.sh"

require_root
load_config

source /etc/projet-soutenance/service-accounts.env

FR_DIR="/etc/freeradius/3.0"

log_info "Arret de FreeRADIUS pendant la configuration..."

log_info "Activation du module LDAP..."

if [[ ! -L "$FR_DIR/mods-enabled/ldap" ]]; then
    ln -s "$FR_DIR/mods-available/ldap" "$FR_DIR/mods-enabled/ldap"
    log_ok "Module LDAP active."
else
    log_ok "Module LDAP deja active."
fi

log_info "Configuration du module LDAP..."

LDAP_MOD="$FR_DIR/mods-available/ldap"

if [[ ! -f "$LDAP_MOD.orig" ]]; then
    cp "$LDAP_MOD" "$LDAP_MOD.orig"
fi

sed -i "s|^\(\s*\)server = .*|\1server = 'localhost'|" "$LDAP_MOD"

if grep -qE "^\s*identity\s*=" "$LDAP_MOD"; then
    sed -i "s|^\(\s*\)identity\s*=.*|\1identity = '$RADIUS_BIND_DN'|" "$LDAP_MOD"
else
    sed -i "s|^#\(\s*\)identity\s*=.*|\1identity = '$RADIUS_BIND_DN'|" "$LDAP_MOD"
fi

if grep -qE "^\s*password\s*=" "$LDAP_MOD"; then
    sed -i "s|^\(\s*\)password\s*=.*|\1password = $RADIUS_BIND_PASSWORD|" "$LDAP_MOD"
else
    sed -i "s|^#\(\s*\)password\s*=.*|\1password = $RADIUS_BIND_PASSWORD|" "$LDAP_MOD"
fi

sed -i "s|^\(\s*\)base_dn = .*|\1base_dn = '$LDAP_BASE_DN'|" "$LDAP_MOD"

if awk '
    /filter[[:space:]]*=/ && /(uid=|mail=)/ {
        sub(/^[[:space:]]*#[[:space:]]*/, "")
        sub(/uid=/, "mail=")
        found=1
    }
    { print }
    END { if (!found) exit 1 }
' "$LDAP_MOD" > "${LDAP_MOD}.new"; then
    mv "${LDAP_MOD}.new" "$LDAP_MOD"
else
    rm -f "${LDAP_MOD}.new"
    die "Filtre utilisateur LDAP introuvable dans $LDAP_MOD."
fi

log_ok "Module LDAP configure."

log_info "Activation de LDAP dans le site par defaut..."

DEFAULT_SITE="$FR_DIR/sites-available/default"

if [[ ! -f "$DEFAULT_SITE.orig" ]]; then
    cp "$DEFAULT_SITE" "$DEFAULT_SITE.orig"
fi

awk '
    /^authorize[[:space:]]*\{/ { in_auth=1 }
    in_auth && /^[[:space:]]*#[[:space:]]*ldap[[:space:]]*$/ { sub(/#[[:space:]]*ldap/, "ldap"); in_auth=0 }
    { print }
' "$DEFAULT_SITE.orig" > "$DEFAULT_SITE"

awk '
    /^authenticate[[:space:]]*\{/ { in_auth=1 }
    in_auth && /^[[:space:]]*#[[:space:]]*Auth-Type LDAP[[:space:]]*\{/ { print "        Auth-Type LDAP {"; skip=1; next }
    skip && /^[[:space:]]*#[[:space:]]*ldap[[:space:]]*$/ { print "                ldap"; next }
    skip && /^[[:space:]]*#[[:space:]]*\}/ { print "        }"; skip=0; in_auth=0; next }
    { print }
' "$DEFAULT_SITE" > "${DEFAULT_SITE}.new"
mv "${DEFAULT_SITE}.new" "$DEFAULT_SITE"

log_ok "Site par defaut configure."

log_info "Verification du client localhost..."

CLIENTS_FILE="$FR_DIR/clients.conf"
awk -v secret="$RADIUS_SHARED_SECRET" '
    /^client localhost[[:space:]]*\{/ { in_block=1 }
    in_block && /^[[:space:]]*secret[[:space:]]*=/ { sub(/=.*/, "= " secret) }
    in_block && /^[[:space:]]*require_message_authenticator[[:space:]]*=/ { sub(/=.*/, "= yes") }
    in_block && /^}/ { in_block=0 }
    { print }
' "$CLIENTS_FILE" > "${CLIENTS_FILE}.new"
mv "${CLIENTS_FILE}.new" "$CLIENTS_FILE"
log_ok "Client localhost configure."

log_info "Ouverture des ports RADIUS dans UFW..."

if command -v ufw >/dev/null 2>&1; then
    ufw allow 1812/udp >/dev/null 2>&1 || true
    ufw allow 1813/udp >/dev/null 2>&1 || true
    log_ok "Ports RADIUS ouverts."
fi

log_info "Verification de la configuration FreeRADIUS..."

if ! freeradius -C >/dev/null 2>&1; then
    log_error "Configuration FreeRADIUS invalide. Verifier $FR_DIR."
    freeradius -C 2>&1 | tail -20
    exit 1
fi

log_ok "Configuration FreeRADIUS valide."

log_info "Demarrage de FreeRADIUS..."

systemctl enable freeradius >/dev/null 2>&1
systemctl restart freeradius
sleep 2

if systemctl is-active --quiet freeradius; then
    log_ok "FreeRADIUS actif."
else
    log_error "FreeRADIUS n'a pas demarre. Verification des logs :"
    journalctl -u freeradius --no-pager | tail -10
    exit 1
fi

log_info "Test d'authentification RADIUS reussie..."

if radtest "enseignant01@$LDAP_DOMAIN" "$USER_PASSWORD" localhost 0 "$RADIUS_SHARED_SECRET" 2>/dev/null | grep -q "Access-Accept"; then
    log_ok "Authentification PAP par email reussie."
else
    log_error "Authentification PAP par email ECHOUE."
    exit 1
fi

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
