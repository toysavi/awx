#!/bin/bash
set -euo pipefail
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

BACKUP_DIR="${BACKUP_DIR:-/var/backups/awx}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="${BACKUP_DIR}/${TIMESTAMP}"
GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }

echo -e "\n${CYAN}══════════════════════════════════\n  AWX Backup — ${TIMESTAMP}\n══════════════════════════════════${NC}\n"
mkdir -p "${BACKUP_PATH}"

# ── PostgreSQL ──────────────────────────────────────────────
info "Backing up PostgreSQL..."
PG_POD=$(kubectl get pods -n awx -l app.kubernetes.io/name=awx-postgres \
  --no-headers -o custom-columns=":metadata.name" | head -1)
if [[ -n "$PG_POD" ]]; then
  kubectl exec -n awx "${PG_POD}" -- pg_dump -U awx awx > "${BACKUP_PATH}/awx_db.sql"
  gzip "${BACKUP_PATH}/awx_db.sql"
  success "Database: awx_db.sql.gz"
else
  echo "WARNING: PostgreSQL pod not found"
fi

# ── Secrets ─────────────────────────────────────────────────
info "Backing up secrets..."
kubectl get secrets -n awx -o yaml > "${BACKUP_PATH}/awx_secrets.yaml"
success "Secrets: awx_secrets.yaml"

# ── ConfigMaps ──────────────────────────────────────────────
info "Backing up configmaps..."
kubectl get configmaps -n awx -o yaml > "${BACKUP_PATH}/awx_configmaps.yaml"
success "ConfigMaps: awx_configmaps.yaml"

# ── AWX CR ──────────────────────────────────────────────────
info "Backing up AWX Custom Resource..."
kubectl get awx -n awx -o yaml > "${BACKUP_PATH}/awx_cr.yaml"
success "CR: awx_cr.yaml"

# ── Traefik config ──────────────────────────────────────────
info "Backing up Traefik config..."
kubectl get ingressroute -A -o yaml > "${BACKUP_PATH}/traefik_ingressroutes.yaml"
kubectl get middleware -A -o yaml > "${BACKUP_PATH}/traefik_middleware.yaml"
success "Traefik config backed up"

# ── Cleanup old backups ─────────────────────────────────────
info "Keeping last 7 backups..."
ls -dt "${BACKUP_DIR}"/*/  2>/dev/null | tail -n +8 | xargs rm -rf || true

SIZE=$(du -sh "${BACKUP_PATH}" | cut -f1)
echo ""
success "Backup complete: ${BACKUP_PATH} (${SIZE})"
ls -lh "${BACKUP_PATH}/"
echo ""
