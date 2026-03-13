#!/bin/bash
# ============================================================
#  AWX Import — Apply all config from YAML files
# ============================================================
set -euo pipefail

CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }

export CONTROLLER_HOST="${CONTROLLER_HOST:-https://awx.$(curl -s ifconfig.me).nip.io}"
export CONTROLLER_USERNAME="${CONTROLLER_USERNAME:-admin}"
export CONTROLLER_PASSWORD="${CONTROLLER_PASSWORD:?Set CONTROLLER_PASSWORD}"
export CONTROLLER_VERIFY_SSL="${CONTROLLER_VERIFY_SSL:-false}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo -e "${CYAN}══════════════════════════════════${NC}"
echo -e "${CYAN}  AWX Import — ${CONTROLLER_HOST}${NC}"
echo -e "${CYAN}══════════════════════════════════${NC}"
echo ""

if ! command -v ansible-playbook &>/dev/null; then
  warn "ansible not found, installing..."
  pip3 install ansible awxkit -q
  ansible-galaxy collection install awx.awx -q
fi

info "Running configure-all.yml..."
ansible-playbook "${SCRIPT_DIR}/configure-all.yml" \
  -e "controller_host=${CONTROLLER_HOST}" \
  -e "controller_username=${CONTROLLER_USERNAME}" \
  -e "controller_password=${CONTROLLER_PASSWORD}" \
  -e "controller_verify_ssl=false" \
  "$@"

success "Import complete!"
echo ""
