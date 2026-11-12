#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export PROJECT_ROOT

source "${SCRIPT_DIR}/lib-test.sh"

if [[ $EUID -ne 0 ]]; then
    echo "Ce script doit etre lance en root (sudo)."
    exit 1
fi

load_config


echo "Suite de tests - Serveur pedagogique"

source "$SCRIPT_DIR/test-system.sh"
echo
source "$SCRIPT_DIR/test-ldap.sh"
echo
source "$SCRIPT_DIR/test-samba.sh"
echo
source "$SCRIPT_DIR/test-radius.sh"

echo "Rapport final"
echo "Tests reussis : $TESTS_PASSED"
echo "Tests echoues : $TESTS_FAILED"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo "Resultat global : OK"
    exit 0
else
    echo "Resultat global : KO"
    exit 1
fi
