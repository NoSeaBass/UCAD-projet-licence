#!/usr/bin/env bash
# Lance tous les tests et affiche le rapport final.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export PROJECT_ROOT

source "${SCRIPT_DIR}/../scripts/lib.sh"
source "${SCRIPT_DIR}/lib-test.sh"

if [[ $EUID -ne 0 ]]; then
    echo "Ce script doit etre lance en root (sudo)."
    exit 1
fi

load_config


echo " Suite de tests - Serveur pedagogique"
echo ""

source "$SCRIPT_DIR/test-system.sh"
echo
source "$SCRIPT_DIR/test-ldap.sh"
echo
source "$SCRIPT_DIR/test-samba.sh"
echo
source "$SCRIPT_DIR/test-radius.sh"

echo ""
echo ""
echo " Rapport final"
echo ""
echo -e "${GREEN}Tests reussis :${NC} $TESTS_PASSED"
echo -e "${RED}Tests echoues :${NC} $TESTS_FAILED"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}Resultat global : OK${NC}"
    exit 0
else
    echo -e "${RED}Resultat global : KO${NC}"
    exit 1
fi
