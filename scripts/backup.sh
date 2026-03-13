#!/bin/bash
set -euo pipefail

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

BACKUP_DIR="${BACKUP_DIR:-/var/backups/awx}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="${BACKUP_DIR}/${TIMESTAMP}"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }

echo ""
echo -e "${CYAN}══════════════════════════════════${NC}"
echo -e "${CYAN}  AWX Backup — ${TIMESTAMP}${NC}"
echo -e "${CYAN}══════════════════════════════════${NC}"
echo ""

mkdir -p "${BACKUP_PATH}"

# ── PostgreSQL dump ─────────────────────────────────────────
info "Backing up PostgreSQL..."
POSTGRES_POD=$(kubectl get pods -n awx -l app.kubernetes.io/name=awx-postgres \
  --no-headers -o custom-columns=":metadata.name" | head -1)

if [[ -n "$POSTGRES_POD" ]]; then
  kubectl exec -n awx "${POSTGRES_POD}" -- \
    pg_dump -U awx awx > "${BACKUP_PATH}/awx_db.sql"
  gzip "${BACKUP_PATH}/awx_db.sql"
  success "Database backed up: awx_db.sql.gz"
else
  echo "WARNING: PostgreSQL pod not found, skipping DB backup"
fi

# ── AWX secrets ─────────────────────────────────────────────
info "Backing up AWX secrets..."
kubectl get secrets -n awx -o yaml > "${BACKUP_PATH}/awx_secrets.yaml"
success "Secrets backed up: awx_secrets.yaml"

# ── AWX configmaps ──────────────────────────────────────────
info "Backing up AWX configmaps..."
kubectl get configmaps -n awx -o yaml > "${BACKUP_PATH}/awx_configmaps.yaml"
success "ConfigMaps backed up: awx_configmaps.yaml"

# ── AWX CR ──────────────────────────────────────────────────
info "Backing up AWX Custom Resource..."
kubectl get awx -n awx -o yaml > "${BACKUP_PATH}/awx_cr.yaml"
success "CR backed up: awx_cr.yaml"

# ── Cleanup old backups (keep last 7) ───────────────────────
info "Cleaning old backups (keeping last 7)..."
ls -dt "${BACKUP_DIR}"/*/  2>/dev/null | tail -n +8 | xargs rm -rf || true

# ── Summary ─────────────────────────────────────────────────
BACKUP_SIZE=$(du -sh "${BACKUP_PATH}" | cut -f1)
echo ""
success "Backup complete: ${BACKUP_PATH} (${BACKUP_SIZE})"
echo ""
ls -lh "${BACKUP_PATH}/"
echo ""
