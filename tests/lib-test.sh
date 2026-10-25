#!/usr/bin/env bash
# Bibliothèque de fonctions pour les tests.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../scripts/lib.sh"

: "${TESTS_PASSED:=0}"
: "${TESTS_FAILED:=0}"

test_ok() {
    printf "%b\n" "${GREEN}[OK]${NC} $*"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

test_ko() {
    printf "%b\n" "${RED}[KO]${NC} $*"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

assert_service_active() {
    local service="$1"
    if systemctl is-active --quiet "$service"; then
        test_ok "Service $service actif"
    else
        test_ko "Service $service inactif"
    fi
}

assert_command_success() {
    local description="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        test_ok "$description"
    else
        test_ko "$description"
    fi
}

assert_file_exists() {
    local file="$1"
    if [[ -f "$file" ]]; then
        test_ok "Fichier $file present"
    else
        test_ko "Fichier $file manquant"
    fi
}

assert_dir_exists() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        test_ok "Repertoire $dir present"
    else
        test_ko "Repertoire $dir manquant"
    fi
}
