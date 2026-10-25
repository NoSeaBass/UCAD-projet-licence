#!/usr/bin/env bash
# Configure le système de base : hostname, timezone, paquets.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export PROJECT_ROOT

source "${SCRIPT_DIR}/lib.sh"

require_root
load_config

log_info "Configuration du hostname..."
hostnamectl set-hostname "$HOSTNAME"

log_info "Configuration du timezone..."
timedatectl set-timezone "$TIMEZONE"

log_info "Configuration du réseau..."
INTERFACE=$(ip route | awk '/default/ {print $5; exit}')
if [[ -z "$INTERFACE" ]]; then
    die "Impossible de détecter l'interface réseau principale."
fi
log_info "Interface détectée : $INTERFACE"

mkdir -p /etc/cloud/cloud.cfg.d
printf '%s\n' 'network: {config: disabled}' > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg

shopt -s nullglob
for f in /etc/netplan/*.yaml; do
    [[ "$f" == "/etc/netplan/01-projet-soutenance.yaml" ]] && continue
    backup_file "$f"
    rm -f "$f"
done
shopt -u nullglob

NETPLAN_FILE="/etc/netplan/01-projet-soutenance.yaml"
if [[ -f "$NETPLAN_FILE" ]] && [[ ! -f "${NETPLAN_FILE}.orig" ]]; then
    cp "$NETPLAN_FILE" "${NETPLAN_FILE}.orig"
fi

if [[ -n "$IP_ADDRESS" ]]; then
    IP_ADDRESS_CIDR="$IP_ADDRESS"
    if [[ "$IP_ADDRESS" != */* ]]; then
        IP_ADDRESS_CIDR="${IP_ADDRESS}/24"
    fi

    cat > "$NETPLAN_FILE" <<EOF
network:
  version: 2
  ethernets:
    ${INTERFACE}:
      dhcp4: false
      addresses:
        - ${IP_ADDRESS_CIDR}
      routes:
        - to: default
          via: ${GATEWAY}
      nameservers:
        addresses: [$(echo "$DNS_SERVERS" | tr ' ' ',')]
EOF
    log_info "Configuration IP fixe : $IP_ADDRESS_CIDR"
else
    cat > "$NETPLAN_FILE" <<EOF
network:
  version: 2
  ethernets:
    ${INTERFACE}:
      dhcp4: true
EOF
    log_info "Configuration DHCP."
fi

chmod 600 "$NETPLAN_FILE"

if ! netplan generate 2>/tmp/netplan-error.log; then
    log_error "Configuration netplan invalide :"
    cat /tmp/netplan-error.log
    if [[ -f "${NETPLAN_FILE}.orig" ]]; then
        cp "${NETPLAN_FILE}.orig" "$NETPLAN_FILE"
    fi
    die "Corrigez la configuration réseau et relancez."
fi

netplan apply
sleep 2
log_ok "Réseau configuré."

log_info "Mise à jour de l'index des paquets..."
apt-get update -qq

log_info "Installation des paquets de base..."
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    ca-certificates \
    slapd ldap-utils \
    samba samba-common-bin smbclient \
    sssd sssd-ldap sssd-tools libnss-sss libpam-sss \
    freeradius freeradius-ldap freeradius-utils \
    acl ufw

log_ok "Système de base configuré."
