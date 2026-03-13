#!/usr/bin/env bash
# scripts/backup.sh
# ============================================================
# Backup AWX PostgreSQL database and projects.
# Run manually or schedule via cron:
#   0 2 * * * /awx-docker/scripts/backup.sh >> /var/log/awx-backup.log 2>&1
# ============================================================
set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

BACKUP_DIR="${BACKUP_DIR:-/var/backups/awx}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="${BACKUP_DIR}/${TIMESTAMP}"

mkdir -p "$BACKUP_PATH"

# Load env
[[ -f .env ]] || error ".env not found"
source .env

info "=== AWX Backup: $TIMESTAMP ==="

# ── PostgreSQL dump ───────────────────────────────────────────
info "Backing up PostgreSQL..."
docker compose exec -T postgres pg_dump \
  -U "${POSTGRES_USER:-awx}" \
  -d "${POSTGRES_DB:-awx}" \
  --no-password \
  --format=custom \
  --compress=9 \
  > "${BACKUP_PATH}/awx_db.dump"

info "Database backup: ${BACKUP_PATH}/awx_db.dump ($(du -h "${BACKUP_PATH}/awx_db.dump" | cut -f1))"

# ── AWX Projects ──────────────────────────────────────────────
info "Backing up AWX projects..."
docker run --rm \
  -v awx-docker_awx_projects:/data:ro \
  -v "${BACKUP_PATH}:/backup" \
  alpine tar czf /backup/awx_projects.tar.gz -C /data .

info "Projects backup: ${BACKUP_PATH}/awx_projects.tar.gz"

# ── Cleanup old backups (keep last 7 days) ────────────────────
find "$BACKUP_DIR" -maxdepth 1 -type d -mtime +7 -exec rm -rf {} + 2>/dev/null || true
info "Old backups cleaned (keeping last 7 days)"

info "=== Backup complete: $BACKUP_PATH ==="

# ── Restore instructions ──────────────────────────────────────
echo ""
info "To restore:"
info "  docker compose exec -T postgres pg_restore \\"
info "    -U awx -d awx --clean ${BACKUP_PATH}/awx_db.dump"
