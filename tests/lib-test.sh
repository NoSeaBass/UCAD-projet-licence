#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../scripts/lib.sh"

: "${TESTS_PASSED:=0}"
: "${TESTS_FAILED:=0}"

test_ok() {
    printf '[OK] %s\n' "$*"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

test_ko() {
    printf '[KO] %s\n' "$*"
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

assert_dir_exists() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        test_ok "Repertoire $dir present"
    else
        test_ko "Repertoire $dir manquant"
    fi
}
