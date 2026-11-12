#!/usr/bin/env bash
set -euo pipefail

export TERM="${TERM:-linux}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export PROJECT_ROOT
source "${SCRIPT_DIR}/lib.sh"

MARKER_DIR="/etc/projet-soutenance"
MARKER="$MARKER_DIR/configured"
mkdir -p "$MARKER_DIR"

prompt_samba_name() {
    local result
    local default="${HOSTNAME^^}"
    default="${default:0:15}"
    result=$(whiptail --title "Identifiant du domaine Samba" --inputbox \
        "Nom NetBIOS utilise par Samba et son entree LDAP (1 a 15 caracteres : A-Z, 0-9, tiret) :" \
        10 70 "${SAMBA_NETBIOS_NAME:-$default}" 3>&1 1>&2 2>&3) || exit 1
    result="${result^^}"
    if [[ ! "$result" =~ ^[A-Z0-9]([A-Z0-9-]{0,13}[A-Z0-9])?$ ]]; then
        whiptail --title "Erreur" --msgbox "Nom invalide. Utilisez 1 a 15 lettres, chiffres ou tirets." 10 65
        prompt_samba_name
        return
    fi
    printf '%s' "$result"
}

if [[ ! -f "${PROJECT_ROOT}/config/config.env" ]]; then
    cp "${PROJECT_ROOT}/config/config.env.example" "${PROJECT_ROOT}/config/config.env"
fi

source "${PROJECT_ROOT}/config/config.env"

if [[ -z "$RADIUS_SHARED_SECRET" ]]; then
    RADIUS_SHARED_SECRET="$(openssl rand -hex 16)"
fi

whiptail --title "Bienvenue" --msgbox "\
Bienvenue sur le serveur pedagogique.\n\n\
Ce script va configurer les services : OpenLDAP, Samba, FreeRADIUS, et la securite.\n\n\
Il vous sera demande quelques informations. Des valeurs par defaut sont proposees.\n\n\
Vous pourrez changer le mot de passe administrateur LDAP apres la configuration.\n\
Les mots de passe par defaut sont 'admin' et 'user' pour les utilisateurs de test\n\n\
Je conseil de changer les mots de passes avant deploiement\n\n\
Appuyez sur Entree pour continuer." 25 75

NEW_HOSTNAME=$(whiptail --title "Nom du serveur" --inputbox \
    "Nom du serveur (hostname) :" 10 60 "$HOSTNAME" 3>&1 1>&2 2>&3)
HOSTNAME="${NEW_HOSTNAME:-$HOSTNAME}"

LDAP_ADMIN_PASSWORD=$(whiptail --title "Mot de passe LDAP admin" --passwordbox \
    "Mot de passe pour cn=admin (LDAP) :" 10 60 "$LDAP_ADMIN_PASSWORD" 3>&1 1>&2 2>&3)

USER_PASSWORD=$(whiptail --title "Mot de passe des utilisateurs de test" --passwordbox \
    "Mot de passe pour enseignant01, apprenant01, etc. :" 10 60 "$USER_PASSWORD" 3>&1 1>&2 2>&3)

SAMBA_NETBIOS_NAME=$(prompt_samba_name)
CONFIG_FILE="${PROJECT_ROOT}/config/config.env"

cat > "$CONFIG_FILE" <<EOF
HOSTNAME="$HOSTNAME"

LDAP_DOMAIN="$LDAP_DOMAIN"
LDAP_BASE_DN="$LDAP_BASE_DN"
LDAP_ADMIN_DN="$LDAP_ADMIN_DN"
LDAP_ADMIN_PASSWORD="$LDAP_ADMIN_PASSWORD"

SAMBA_WORKGROUP="$SAMBA_WORKGROUP"
SAMBA_NETBIOS_NAME="$SAMBA_NETBIOS_NAME"

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

whiptail --title "Confirmation" --yesno "\
Configuration a appliquer :\n\n\
Hostname : $HOSTNAME\n\
Identifiant Samba : $SAMBA_NETBIOS_NAME\n\
Les scripts system, openldap, samba, freeradius,
integration et security vont maintenant s'executer.\n\n\
Cela peut prendre 10 a 20 minutes.\n\n\
Continuer ?" 20 70

if [[ $? -ne 0 ]]; then
    echo "Configuration annulee par l'utilisateur."
    exit 1
fi

echo ""
echo "Nous passons a l'execution des scripts de configuration... Cela va prendre du temps merci de patienter"
echo ""

for script in system.sh openldap.sh samba.sh freeradius.sh integration.sh security.sh; do
    echo "=== Execution de $script ==="
    if ! bash "${SCRIPT_DIR}/${script}"; then
        whiptail --title "Erreur Critique" --msgbox "Le script $script a echoue.\n\nVerifiez les logs sur la console (Alt+F2) ou dans /var/log/syslog.\nL'installation est interrompue." 15 70
        exit 1
    fi
done

touch "$MARKER"

systemctl disable projet-soutenance.service 2>/dev/null || true

whiptail --title "Termine" --msgbox "\
Configuration terminee.\n\n\
Pour verifier : sudo bash /opt/projet-soutenance/tests/run-tests.sh\n\n\
Appuyez sur Entree pour fermer." 15 70

systemctl reboot
