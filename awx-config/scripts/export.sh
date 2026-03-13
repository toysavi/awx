#!/bin/bash
# ============================================================
#  AWX Export — Dump current AWX config to YAML files
#  Uses: awxkit (pip3 install awxkit)
# ============================================================
set -euo pipefail

CYAN='\033[0;36m'; GREEN='\033[0;32m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }

export CONTROLLER_HOST="${CONTROLLER_HOST:-https://awx.$(curl -s ifconfig.me).nip.io}"
export CONTROLLER_USERNAME="${CONTROLLER_USERNAME:-admin}"
export CONTROLLER_PASSWORD="${CONTROLLER_PASSWORD:?Set CONTROLLER_PASSWORD}"
export CONTROLLER_VERIFY_SSL="${CONTROLLER_VERIFY_SSL:-false}"

EXPORT_DIR="$(dirname "$0")/../export_$(date +%Y%m%d_%H%M%S)"
mkdir -p "${EXPORT_DIR}"

echo ""
echo -e "${CYAN}══════════════════════════════════${NC}"
echo -e "${CYAN}  AWX Export — ${CONTROLLER_HOST}${NC}"
echo -e "${CYAN}══════════════════════════════════${NC}"
echo ""

if ! command -v awx &>/dev/null; then
  info "Installing awxkit..."
  pip3 install awxkit -q
fi

# Export all resources
for resource in organizations teams users credentials inventory_sources \
                inventories projects job_templates workflow_job_templates \
                notification_templates schedules; do
  info "Exporting ${resource}..."
  awx export \
    --conf.host "${CONTROLLER_HOST}" \
    --conf.username "${CONTROLLER_USERNAME}" \
    --conf.password "${CONTROLLER_PASSWORD}" \
    --conf.insecure \
    --${resource} \
    > "${EXPORT_DIR}/${resource}.json" 2>/dev/null || echo "  (skipped: ${resource})"
done

success "Export complete: ${EXPORT_DIR}"
echo ""
ls -lh "${EXPORT_DIR}/"
echo ""
