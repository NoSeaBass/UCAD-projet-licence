#!/usr/bin/env bash
# Configuration interactive du serveur pedagogique au premier demarrage.

set -euo pipefail

export TERM="${TERM:-linux}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export PROJECT_ROOT
source "${SCRIPT_DIR}/lib.sh"

MARKER_DIR="/etc/projet-soutenance"
MARKER="$MARKER_DIR/configured"
mkdir -p "$MARKER_DIR"

# --- Fonctions de validation ---
validate_ip_cidr() {
    local ip="$1"
    # Format attendu : X.X.X.X/Y
    if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        return 0
    fi
    return 1
}

validate_ip() {
    local ip="$1"
    if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        return 0
    fi
    return 1
}

prompt_ip_cidr() {
    local title="$1"
    local prompt="$2"
    local default="$3"
    local result
    while true; do
        result=$(whiptail --title "$title" --inputbox "$prompt" 10 60 "$default" 3>&1 1>&2 2>&3)
        if [[ -z "$result" ]]; then
            # L'utilisateur a annule
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

# --- Verification de whiptail ---

if ! command -v whiptail >/dev/null 2>&1; then
    echo "whiptail est requis. Installation..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y whiptail
fi

# --- Chargement de la configuration par defaut ---
# On part de config.env.example et on le copie vers config.env
if [[ ! -f "${PROJECT_ROOT}/config/config.env" ]]; then
    cp "${PROJECT_ROOT}/config/config.env.example" "${PROJECT_ROOT}/config/config.env"
fi

# shellcheck disable=SC1090
source "${PROJECT_ROOT}/config/config.env"

# --- Introduction ---
whiptail --title "Bienvenue" --msgbox "\
Bienvenue sur le serveur pedagogique.\n\n\
Ce script va configurer les services : OpenLDAP, Samba, FreeRADIUS, et la securite.\n\n\
Il vous sera demande quelques informations. Des valeurs par defaut sont proposees.\n\n\
IMPORTANT : apres la configuration, lisez le README :\n\
    cat /opt/projet-soutenance/README.md\n\
Il contient des informations sur la securite et l'utilisation du serveur.\n\n\
Vous pourrez changer le mot de passe administrateur LDAP apres la configuration.\n\
Les mots de passe par defaut sont 'admin' et 'user' pour les utilisateurs de test\n\n\
Je conseil de changer les mots de passes avant deploiement\n\n\
Appuyez sur Entree pour continuer." 25 75

# --- Hostname ---
NEW_HOSTNAME=$(whiptail --title "Nom du serveur" --inputbox \
    "Nom du serveur (hostname) :" 10 60 "$HOSTNAME" 3>&1 1>&2 2>&3)
HOSTNAME="${NEW_HOSTNAME:-$HOSTNAME}"

# --- Timezone ---
# whiptail ne propose pas de selecteur de timezone natif.
# On propose une liste des timezones les plus courantes,
# avec une option "autre" pour saisie manuelle.

TZ_CHOICE=$(whiptail --title "Fuseau horaire" --menu \
    "Choisissez votre fuseau horaire :" 20 70 10 \
    "Africa/Dakar" "Senegal (GMT)" \
    "Africa/Abidjan" "Cote d'Ivoire (GMT)" \
    "Africa/Bamako" "Mali (GMT)" \
    "Africa/Ouagadougou" "Burkina Faso (GMT)" \
    "Africa/Lome" "Togo (GMT)" \
    "Africa/Casablanca" "Maroc (GMT+1)" \
    "Africa/Alger" "Algerie (GMT+1)" \
    "Africa/Tunis" "Tunisie (GMT+1)" \
    "Europe/Paris" "France (GMT+1/+2)" \
    "autre" "Autre (saisie manuelle)" 3>&1 1>&2 2>&3)

if [[ "$TZ_CHOICE" == "autre" ]]; then
    TIMEZONE=$(whiptail --title "Fuseau horaire" --inputbox \
        "Entrez votre fuseau horaire (ex: Europe/London) :" 10 60 "$TIMEZONE" 3>&1 1>&2 2>&3)
else
    TIMEZONE="$TZ_CHOICE"
fi

if [[ -z "$TIMEZONE" ]]; then
    TIMEZONE="Africa/Dakar"
fi

# --- Reseau ---
# Detecter l'IP et la passerelle actuelles
DETECTED_IP=$(ip -4 addr show "$(ip route | awk '/default/ {print $5; exit}')" 2>/dev/null | awk '/inet / {print $2; exit}' || true)
DETECTED_GW=$(ip route | awk '/default/ {print $3; exit}' || true)
DETECTED_DNS=$(resolvectl status 2>/dev/null | awk '/DNS Servers/ {print $3; exit}' || true)

# Utiliser ces valeurs comme defaut si config.env est vide
IP_ADDRESS="${IP_ADDRESS:-$DETECTED_IP}"
GATEWAY="${GATEWAY:-$DETECTED_GW}"
DNS_SERVERS="${DNS_SERVERS:-$DETECTED_DNS}"

# Detecter le mode actuel
CURRENT_MODE="dhcp"
if ip route | grep -q "via"; then
    if ! ip a | grep -q "dynamic"; then
        CURRENT_MODE="static"
    fi
fi

if ! NET_MODE=$(whiptail --title "Configuration reseau" --menu \
    "Choisissez le mode de configuration reseau :\n\
    (mode actuel detecte : $CURRENT_MODE)" 17 70 3 \
    "keep" "Conserver la configuration actuelle" \
    "dhcp" "DHCP (automatique)" \
    "static" "IP fixe" 3>&1 1>&2 2>&3); then
    log_error "Configuration annulee par l'utilisateur."
    exit 1
fi

if [[ "$NET_MODE" == "keep" ]]; then
    log_info "Configuration reseau conservee."
elif [[ "$NET_MODE" == "static" ]]; then
    IP_ADDRESS=$(prompt_ip_cidr "Adresse IP" \
        "Adresse IP (CIDR, ex: 192.168.122.10/24) :" "$IP_ADDRESS")
    GATEWAY=$(prompt_ip "Passerelle" \
        "Passerelle (ex: 192.168.122.1) :" "$GATEWAY")
    DNS_SERVERS=$(whiptail --title "Serveurs DNS" --inputbox \
        "Serveurs DNS (separes par espace) :" 10 60 "$DNS_SERVERS" 3>&1 1>&2 2>&3)
else
    # dhcp
    IP_ADDRESS=""
    GATEWAY=""
    DNS_SERVERS=""
fi

# --- Mot de passe LDAP admin ---
LDAP_ADMIN_PASSWORD=$(whiptail --title "Mot de passe LDAP admin" --passwordbox \
    "Mot de passe pour cn=admin (LDAP) :" 10 60 "$LDAP_ADMIN_PASSWORD" 3>&1 1>&2 2>&3)

# --- Mot de passe des utilisateurs de test ---
USER_PASSWORD=$(whiptail --title "Mot de passe des utilisateurs de test" --passwordbox \
    "Mot de passe pour enseignant01, apprenant01, etc. :" 10 60 "$USER_PASSWORD" 3>&1 1>&2 2>&3)

# --- Ecriture du config.env ---
CONFIG_FILE="${PROJECT_ROOT}/config/config.env"

cat > "$CONFIG_FILE" <<EOF
# Configuration generee par configure.sh le $(date)

HOSTNAME="$HOSTNAME"
TIMEZONE="$TIMEZONE"

IP_ADDRESS="$IP_ADDRESS"
NETMASK="$NETMASK"
GATEWAY="$GATEWAY"
DNS_SERVERS="$DNS_SERVERS"

LDAP_DOMAIN="$LDAP_DOMAIN"
LDAP_BASE_DN="$LDAP_BASE_DN"
LDAP_ADMIN_DN="$LDAP_ADMIN_DN"
LDAP_ADMIN_PASSWORD="$LDAP_ADMIN_PASSWORD"

SAMBA_WORKGROUP="$SAMBA_WORKGROUP"
SAMBA_NETBIOS_NAME="$(echo "${HOSTNAME^^}" | cut -c1-15)"

USER_PASSWORD="$USER_PASSWORD"
ENSEIGNANT01_UID=$ENSEIGNANT01_UID
ENSEIGNANT02_UID=$ENSEIGNANT02_UID
APPRENANT01_UID=$APPRENANT01_UID
APPRENANT02_UID=$APPRENANT02_UID
ENSEIGNANTS_GID=$ENSEIGNANTS_GID
APPRENANTS_GID=$APPRENANTS_GID

RADIUS_SHARED_SECRET="$RADIUS_SHARED_SECRET"

SHARES_BASE="$SHARES_BASE"
EOF

chmod 600 "$CONFIG_FILE"

# --- Confirmation ---
whiptail --title "Confirmation" --yesno "\
Configuration a appliquer :\n\n\
Hostname : $HOSTNAME\n\
Reseau : $NET_MODE\n\
IP : $IP_ADDRESS\n\
Passerelle : $GATEWAY\n\n\
Les scripts system, openldap, samba, freeradius,
integration et security vont maintenant s'executer.\n\n\
Cela peut prendre 10 a 20 minutes.\n\n\
Continuer ?" 20 70

if [[ $? -ne 0 ]]; then
    echo "Configuration annulee par l'utilisateur."
    exit 1
fi

# --- Execution des scripts et finalisation ---

echo ""
echo "Nous passons a l'execution des scripts de configuration... Cela va prendre du temps merci de patienter"
echo""

for script in system.sh openldap.sh samba.sh freeradius.sh integration.sh security.sh; do
    echo "=== Execution de $script ==="
    bash "${SCRIPT_DIR}/${script}"
done

touch "$MARKER"

systemctl disable projet-soutenance.service 2>/dev/null || true

whiptail --title "Termine" --msgbox "\
Configuration terminee.\n\n\
Pour verifier : sudo bash /opt/projet-soutenance/tests/run-tests.sh\n\n\
Pour lire la documentation :\n\
cat /opt/projet-soutenance/README.md\n\n\
Appuyez sur Entree pour fermer." 15 70

systemctl reboot
