#!/usr/bin/env bash
# Configure le systeme de base : hostname, timezone, paquets.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export PROJECT_ROOT

source "${SCRIPT_DIR}/lib.sh"

require_root
load_config

# --- hostname ---
log_info "Configuration du hostname..."
hostnamectl set-hostname "$HOSTNAME"

# --- timezone ---
log_info "Configuration du timezone..."
timedatectl set-timezone "$TIMEZONE"

# --- reseau ---
log_info "Configuration du reseau..."

INTERFACE=$(ip route | awk '/default/ {print $5; exit}')
if [[ -z "$INTERFACE" ]]; then
    die "Impossible de detecter l'interface reseau principale."
fi
log_info "Interface detectee : $INTERFACE"

# Desactiver cloud-init pour le reseau (sinon il ecrase la config au boot)
mkdir -p /etc/cloud/cloud.cfg.d
echo 'network: {config: disabled}' > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg

# Sauvegarder puis supprimer les anciens fichiers netplan (sauf le notre)
for f in /etc/netplan/*.yaml; do
    [[ -f "$f" ]] || continue
    [[ "$f" == *"01-projet-soutenance.yaml" ]] && continue
    backup_file "$f"
    rm -f "$f"
done

# Fichier netplan dedie
NETPLAN_FILE="/etc/netplan/01-projet-soutenance.yaml"

# Sauvegarder
if [[ -f "$NETPLAN_FILE" ]] && [[ ! -f "${NETPLAN_FILE}.orig" ]]; then
    cp "$NETPLAN_FILE" "${NETPLAN_FILE}.orig"
fi

# Ecrire la nouvelle configuration
if [[ -n "$IP_ADDRESS" ]]; then
    # Ajouter le masque /24 si absent
    if [[ "$IP_ADDRESS" != */* ]]; then
        IP_ADDRESS_CIDR="${IP_ADDRESS}/24"
    else
        IP_ADDRESS_CIDR="$IP_ADDRESS"
    fi

    cat > "$NETPLAN_FILE" <<EOF
network:
  version: 2
  ethernets:
    $INTERFACE:
      dhcp4: false
      addresses:
        - $IP_ADDRESS_CIDR
      routes:
        - to: default
          via: $GATEWAY
      nameservers:
        addresses: [$(echo "$DNS_SERVERS" | tr ' ' ',')]
EOF
    log_info "Configuration IP fixe : $IP_ADDRESS_CIDR"
else
    cat > "$NETPLAN_FILE" <<EOF
network:
  version: 2
  ethernets:
    $INTERFACE:
      dhcp4: true
EOF
    log_info "Configuration DHCP."
fi

chmod 600 "$NETPLAN_FILE"

# Valider la syntaxe
if ! netplan generate 2>/tmp/netplan-error.log; then
    log_error "Configuration netplan invalide :"
    cat /tmp/netplan-error.log
    if [[ -f "${NETPLAN_FILE}.orig" ]]; then
        cp "${NETPLAN_FILE}.orig" "$NETPLAN_FILE"
    fi
    die "Corrigez la configuration reseau et relancez."
fi

# Appliquer
netplan apply
sleep 2

log_ok "Reseau configure."

# --- finalisation ---
log_info "Mise a jour de l'index des paquets..."
apt-get update -qq

log_info "Installation des paquets de base..."
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    slapd ldap-utils \
    samba samba-common-bin smbclient \
    sssd sssd-ldap sssd-tools libnss-sss libpam-sss \
    freeradius freeradius-ldap freeradius-utils \
    acl ufw

log_ok "Systeme de base configure."
