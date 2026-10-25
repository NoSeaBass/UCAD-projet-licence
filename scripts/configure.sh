#!/usr/bin/env bash
# Configuration interactive du serveur pédagogique au premier démarrage.

set -euo pipefail

export TERM="${TERM:-linux}"
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export PROJECT_ROOT

source "${SCRIPT_DIR}/lib.sh"

MARKER_DIR="/etc/projet-soutenance"
MARKER="$MARKER_DIR/configured"
mkdir -p "$MARKER_DIR"

validate_ip_cidr() {
    local ip="$1"
    is_valid_cidr "$ip"
}

validate_ip() {
    local ip="$1"
    is_valid_ip "$ip"
}

prompt_ip_cidr() {
    local title="$1"
    local prompt="$2"
    local default="$3"
    local result

    while true; do
        result=$(whiptail --title "$title" --inputbox "$prompt" 10 60 "$default" 3>&1 1>&2 2>&3)
        if [[ -z "$result" ]]; then
            echo ""
            return
        fi
        if validate_ip_cidr "$result"; then
            echo "$result"
            return
        fi
        whiptail --title "Erreur" --msgbox "Format invalide. Attendu : X.X.X.X/Y (ex: 192.168.122.10/24)" 10 70
    done
}

prompt_ip() {
    local title="$1"
    local prompt="$2"
    local default="$3"
    local result

    while true; do
        result=$(whiptail --title "$title" --inputbox "$prompt" 10 60 "$default" 3>&1 1>&2 2>&3)
        if [[ -z "$result" ]]; then
            echo ""
            return
        fi
        if validate_ip "$result"; then
            echo "$result"
            return
        fi
        whiptail --title "Erreur" --msgbox "Format invalide. Attendu : X.X.X.X (ex: 192.168.122.1)" 10 70
    done
}

if ! command -v whiptail >/dev/null 2>&1; then
    echo "whiptail est requis. Installation en cours..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y whiptail >/dev/null
fi

if [[ ! -f "${PROJECT_ROOT}/config/config.env" ]]; then
    cp "${PROJECT_ROOT}/config/config.env.example" "${PROJECT_ROOT}/config/config.env"
fi

# shellcheck disable=SC1090
source "${PROJECT_ROOT}/config/config.env"

whiptail --title "Bienvenue" --msgbox "\
Bienvenue sur le serveur pédagogique.\n\n\
Ce script va configurer les services : OpenLDAP, Samba, FreeRADIUS, SSSD et la sécurité.\n\n\
Il vous sera demandé quelques informations. Des valeurs par défaut sont proposées.\n\n\
IMPORTANT : les mots de passe par défaut sont destinés uniquement à une maquette de laboratoire.\n\
En production, remplacez-les avant tout déploiement.\n\n\
Appuyez sur Entrée pour continuer." 24 78

NEW_HOSTNAME=$(whiptail --title "Nom du serveur" --inputbox \
    "Nom du serveur (hostname) :" 10 60 "${HOSTNAME:-serveur-peda}" 3>&1 1>&2 2>&3)
HOSTNAME="${NEW_HOSTNAME:-${HOSTNAME:-serveur-peda}}"

TZ_CHOICE=$(whiptail --title "Fuseau horaire" --menu \
    "Choisissez votre fuseau horaire :" 20 70 10 \
    "Africa/Dakar" "Sénégal (GMT)" \
    "Africa/Abidjan" "Côte d'Ivoire (GMT)" \
    "Africa/Bamako" "Mali (GMT)" \
    "Africa/Ouagadougou" "Burkina Faso (GMT)" \
    "Africa/Lome" "Togo (GMT)" \
    "Africa/Casablanca" "Maroc (GMT+1)" \
    "Africa/Alger" "Algérie (GMT+1)" \
    "Africa/Tunis" "Tunisie (GMT+1)" \
    "Europe/Paris" "France (GMT+1/+2)" \
    "autre" "Autre (saisie manuelle)" 3>&1 1>&2 2>&3)

if [[ "$TZ_CHOICE" == "autre" ]]; then
    TIMEZONE=$(whiptail --title "Fuseau horaire" --inputbox \
        "Entrez votre fuseau horaire (ex: Europe/London) :" 10 60 "${TIMEZONE:-Africa/Dakar}" 3>&1 1>&2 2>&3)
else
    TIMEZONE="$TZ_CHOICE"
fi

TIMEZONE="${TIMEZONE:-Africa/Dakar}"

DETECTED_IP=$(ip -4 addr show "$(ip route | awk '/default/ {print $5; exit}')" 2>/dev/null | awk '/inet / {print $2; exit}' || true)
DETECTED_GW=$(ip route | awk '/default/ {print $3; exit}' || true)
DETECTED_DNS=$(resolvectl status 2>/dev/null | awk '/DNS Servers/ {print $3; exit}' || true)

IP_ADDRESS="${IP_ADDRESS:-$DETECTED_IP}"
GATEWAY="${GATEWAY:-$DETECTED_GW}"
DNS_SERVERS="${DNS_SERVERS:-$DETECTED_DNS}"

CURRENT_MODE="dhcp"
if ip route | grep -q "via"; then
    if ! ip a | grep -q "dynamic"; then
        CURRENT_MODE="static"
    fi
fi

if ! NET_MODE=$(whiptail --title "Configuration réseau" --menu \
    "Choisissez le mode de configuration réseau :\n(mode actuel détecté : $CURRENT_MODE)" 17 70 3 \
    "keep" "Conserver la configuration actuelle" \
    "dhcp" "DHCP (automatique)" \
    "static" "IP fixe" 3>&1 1>&2 2>&3); then
    log_error "Configuration annulée par l'utilisateur."
    exit 1
fi

if [[ "$NET_MODE" == "keep" ]]; then
    log_info "Configuration réseau conservée."
elif [[ "$NET_MODE" == "static" ]]; then
    IP_ADDRESS=$(prompt_ip_cidr "Adresse IP" "Adresse IP (CIDR, ex: 192.168.122.10/24) :" "${IP_ADDRESS:-192.168.122.10/24}")
    GATEWAY=$(prompt_ip "Passerelle" "Passerelle (ex: 192.168.122.1) :" "${GATEWAY:-192.168.122.1}")
    DNS_SERVERS=$(whiptail --title "Serveurs DNS" --inputbox \
        "Serveurs DNS (séparés par espace) :" 10 60 "${DNS_SERVERS:-8.8.8.8}" 3>&1 1>&2 2>&3)
else
    IP_ADDRESS=""
    GATEWAY=""
    DNS_SERVERS=""
fi

LDAP_ADMIN_PASSWORD=$(whiptail --title "Mot de passe LDAP admin" --passwordbox \
    "Mot de passe pour cn=admin (LDAP) :" 10 60 "${LDAP_ADMIN_PASSWORD:-admin}" 3>&1 1>&2 2>&3)
USER_PASSWORD=$(whiptail --title "Mot de passe des utilisateurs de test" --passwordbox \
    "Mot de passe pour enseignant01, apprenant01, etc. :" 10 60 "${USER_PASSWORD:-user}" 3>&1 1>&2 2>&3)

CONFIG_FILE="${PROJECT_ROOT}/config/config.env"

cat > "$CONFIG_FILE" <<EOF
# Configuration générée par configure.sh le $(date)
HOSTNAME="$HOSTNAME"
TIMEZONE="$TIMEZONE"

IP_ADDRESS="$IP_ADDRESS"
NETMASK="${NETMASK:-}"
GATEWAY="$GATEWAY"
DNS_SERVERS="$DNS_SERVERS"

LDAP_DOMAIN="${LDAP_DOMAIN:-etablissement.local}"
LDAP_BASE_DN="${LDAP_BASE_DN:-dc=etablissement,dc=local}"
LDAP_ADMIN_DN="${LDAP_ADMIN_DN:-cn=admin,dc=etablissement,dc=local}"
LDAP_ADMIN_PASSWORD="$LDAP_ADMIN_PASSWORD"

SAMBA_WORKGROUP="${SAMBA_WORKGROUP:-ETABLISSEMENT}"
SAMBA_NETBIOS_NAME="$(echo "${HOSTNAME^^}" | cut -c1-15)"

USER_PASSWORD="$USER_PASSWORD"
ENSEIGNANT01_UID=${ENSEIGNANT01_UID:-10001}
ENSEIGNANT02_UID=${ENSEIGNANT02_UID:-10002}
APPRENANT01_UID=${APPRENANT01_UID:-20001}
APPRENANT02_UID=${APPRENANT02_UID:-20002}
ENSEIGNANTS_GID=${ENSEIGNANTS_GID:-5001}
APPRENANTS_GID=${APPRENANTS_GID:-5002}

RADIUS_SHARED_SECRET="${RADIUS_SHARED_SECRET:-admin}"
SHARES_BASE="${SHARES_BASE:-/srv/partages}"
EOF

chmod 600 "$CONFIG_FILE"

whiptail --title "Confirmation" --yesno "\
Configuration à appliquer :\n\n\
Hostname : $HOSTNAME\n\
Réseau : $NET_MODE\n\
IP : $IP_ADDRESS\n\
Passerelle : $GATEWAY\n\n\
Les scripts system, openldap, samba, freeradius, integration et security vont maintenant s'exécuter.\n\n\
Cela peut prendre 10 à 20 minutes.\n\n\
Continuer ?" 20 70

if [[ $? -ne 0 ]]; then
    echo "Configuration annulée par l'utilisateur."
    exit 1
fi

echo ""
echo "Exécution des scripts de configuration... veuillez patienter."
echo ""

for script in system.sh openldap.sh samba.sh freeradius.sh integration.sh security.sh; do
    echo "=== Exécution de $script ==="
    bash "${SCRIPT_DIR}/${script}"
done

touch "$MARKER"
systemctl disable projet-soutenance.service 2>/dev/null || true

whiptail --title "Terminé" --msgbox "\
Configuration terminée.\n\n\
Pour vérifier :\n\
sudo bash /opt/projet-soutenance/tests/run-tests.sh\n\n\
Pour lire la documentation :\n\
cat /opt/projet-soutenance/README.md\n\n\
Appuyez sur Entrée pour fermer." 16 72

systemctl reboot
