#!/usr/bin/env bash
# Bibliothèque de fonctions communes.

: "${RED:=$'\033[0;31m'}"
: "${GREEN:=$'\033[0;32m'}"
: "${YELLOW:=$'\033[0;33m'}"
: "${NC:=$'\033[0m'}"

log_info() {
    echo "${YELLOW}[INFO]${NC} $*"
}

log_ok() {
    echo "${GREEN}[OK]${NC} $*"
}

log_error() {
    echo "${RED}[ERREUR]${NC} $*" >&2
}

die() {
    log_error "$*"
    exit 1
}

require_root() {
    if [[ $EUID -ne 0 ]]; then
        die "Ce script doit etre lance en root (sudo)."
    fi
}

load_config() {
    local candidates=(
        "${PROJECT_ROOT}/config/config.env"
        "/etc/projet-soutenance/config.env"
    )
    local config_file=""
    for f in "${candidates[@]}"; do
        if [[ -f "$f" ]]; then
            config_file="$f"
            break
        fi
    done
    if [[ -z "$config_file" ]]; then
        die "Fichier de configuration introuvable. Cherche dans : ${candidates[*]}"
    fi
    log_info "Chargement de la configuration : $config_file"
    source "$config_file"
}

check_service() {
    local service="$1"
    if systemctl is-active --quiet "$service"; then
        log_ok "Service $service actif."
    else
        die "Service $service inactif."
    fi
}

backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local backup="${file}.bak.$(date +%Y%m%d-%H%M%S)"
        cp -a "$file" "$backup"
        log_info "Backup : $backup"
    fi
}
