#!/usr/bin/env bash
# scripts/cleanup.sh
# ============================================================
# Full cleanup script — removes all AWX Docker resources.
#
# Usage:
#   ./scripts/cleanup.sh           # Remove containers only
#   ./scripts/cleanup.sh --volumes # Remove containers + volumes (DATA LOSS!)
#   ./scripts/cleanup.sh --all     # Remove everything including images
# ============================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

REMOVE_VOLUMES=false
REMOVE_IMAGES=false

for arg in "$@"; do
  case "$arg" in
    --volumes) REMOVE_VOLUMES=true ;;
    --all)     REMOVE_VOLUMES=true; REMOVE_IMAGES=true ;;
  esac
done

# ── Confirm destructive operations ────────────────────────────
if [[ "$REMOVE_VOLUMES" == "true" ]]; then
  warn "WARNING: This will DELETE all AWX data including:"
  warn "  - PostgreSQL database (all jobs, credentials, inventories)"
  warn "  - AWX projects and playbooks"
  warn "  - Redis data"
  echo ""
  read -rp "Are you sure? Type 'yes' to confirm: " confirm
  [[ "$confirm" == "yes" ]] || { info "Cancelled."; exit 0; }
fi

info "=== Stopping AWX services ==="
docker compose down --remove-orphans 2>/dev/null || true

if [[ "$REMOVE_VOLUMES" == "true" ]]; then
  info "=== Removing volumes (data) ==="
  docker compose down -v 2>/dev/null || true
  docker volume rm \
    awx-docker_postgres_data \
    awx-docker_redis_data \
    awx-docker_awx_projects \
    awx-docker_awx_data \
    2>/dev/null || true
  info "Volumes removed."
fi

if [[ "$REMOVE_IMAGES" == "true" ]]; then
  info "=== Removing AWX Docker images ==="
  docker rmi \
    "quay.io/ansible/awx:$(grep AWX_VERSION .env 2>/dev/null | cut -d= -f2 || echo '24.6.1')" \
    postgres:15-alpine \
    redis:7-alpine \
    nginx:alpine \
    2>/dev/null || true
  info "Images removed."
fi

info "=== Removing orphan containers ==="
docker rm -f awx-web awx-task awx-postgres awx-redis awx-nginx 2>/dev/null || true

info "=== Cleanup complete ==="
echo ""
info "Remaining Docker resources:"
docker ps -a | grep awx || info "  No AWX containers running."
echo ""
info "To redeploy: ./scripts/deploy.sh"
