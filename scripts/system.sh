#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export PROJECT_ROOT

source "${SCRIPT_DIR}/lib.sh"

require_root
load_config

log_info "Configuration du hostname..."
hostnamectl set-hostname "$HOSTNAME"

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
