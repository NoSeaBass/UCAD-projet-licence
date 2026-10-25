#!/usr/bin/env bash
# Bibliothèque de fonctions communes.

set -u

: "${RED:=$'\033[0;31m'}"
: "${GREEN:=$'\033[0;32m'}"
: "${YELLOW:=$'\033[0;33m'}"
: "${BLUE:=$'\033[0;34m'}"
: "${NC:=$'\033[0m'}"

log_info() {
    printf '%b\n' "${YELLOW}[INFO]${NC} $*"
}

log_ok() {
    printf '%b\n' "${GREEN}[OK]${NC} $*"
}

log_warn() {
    printf '%b\n' "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
    printf '%b\n' "${RED}[ERREUR]${NC} $*" >&2
}

die() {
    log_error "$*"
    exit 1
}

require_root() {
    if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
        die "Ce script doit être exécuté en root (sudo)."
    fi
}

ensure_dir() {
    local dir="$1"
    [[ -n "$dir" ]] || die "Le nom de répertoire est vide."
    mkdir -p "$dir"
}

load_config() {
    local candidates=(
        "${PROJECT_ROOT:-/opt/projet-soutenance}/config/config.env"
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
        die "Fichier de configuration introuvable. Vérifiez config/config.env ou /etc/projet-soutenance/config.env."
    fi

    log_info "Chargement de la configuration : $config_file"
    # shellcheck disable=SC1090
    source "$config_file"
}

require_config_var() {
    local var_name="$1"
    local description="${2:-variable}"

    if [[ -z "${!var_name:-}" ]]; then
        die "La variable $description ($var_name) est obligatoire."
    fi
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
    [[ -n "$file" ]] || return 0

    if [[ -f "$file" ]]; then
        local backup="${file}.bak.$(date +%Y%m%d-%H%M%S)"
        cp -a "$file" "$backup"
        log_info "Backup : $backup"
    fi
}

is_valid_ip() {
    local ip="$1"
    [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1

    for octet in ${ip//./ }; do
        (( octet >= 0 && octet <= 255 )) || return 1
    done
    return 0
}

is_valid_cidr() {
    local value="$1"
    [[ "$value" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[1-2][0-9]|3[0-2])$ ]] || return 1
    local ip="${value%/*}"
    is_valid_ip "$ip"
}

has_command() {
    command -v "$1" >/dev/null 2>&1
}
