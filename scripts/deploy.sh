#!/usr/bin/env bash
# scripts/deploy.sh
# ============================================================
# Main deployment script for AWX Docker Compose.
#
# Usage:
#   ./scripts/deploy.sh              # Deploy using .env
#   ./scripts/deploy.sh dev          # Deploy with envs/dev.env
#   ./scripts/deploy.sh staging      # Deploy with envs/staging.env
#   ./scripts/deploy.sh prod         # Deploy with envs/prod.env
#   ./scripts/deploy.sh --update     # Pull new images and redeploy
# ============================================================
set -euo pipefail

# ── Colours ───────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }
section() { echo -e "\n${BLUE}══════════════════════════════════${NC}"; echo -e "${BLUE}  $*${NC}"; echo -e "${BLUE}══════════════════════════════════${NC}"; }

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# ── Parse arguments ───────────────────────────────────────────
ENVIRONMENT=""
UPDATE=false

for arg in "$@"; do
  case "$arg" in
    dev|staging|prod) ENVIRONMENT="$arg" ;;
    --update)         UPDATE=true ;;
    --help|-h)
      echo "Usage: $0 [dev|staging|prod] [--update]"
      exit 0
      ;;
  esac
done

# ── Pre-flight checks ─────────────────────────────────────────
section "Pre-flight Checks"

command -v docker &>/dev/null || error "Docker not found. Run: curl -fsSL https://get.docker.com | sh"
docker compose version &>/dev/null || error "Docker Compose plugin not found. Run: apt-get install -y docker-compose-plugin"

info "Docker version:         $(docker --version)"
info "Docker Compose version: $(docker compose version --short)"

# ── Load environment file ─────────────────────────────────────
section "Loading Environment"

ENV_FILE=".env"

if [[ -n "$ENVIRONMENT" ]]; then
  ENV_OVERLAY="envs/${ENVIRONMENT}.env"
  [[ -f "$ENV_OVERLAY" ]] || error "Environment file not found: $ENV_OVERLAY"

  # Merge base .env.example + overlay + local .env (if exists)
  # Priority: local .env > overlay > defaults
  MERGED_ENV="/tmp/awx-merged-${ENVIRONMENT}.env"
  cat ".env.example" > "$MERGED_ENV"
  cat "$ENV_OVERLAY" >> "$MERGED_ENV"
  [[ -f ".env" ]] && cat ".env" >> "$MERGED_ENV"
  ENV_FILE="$MERGED_ENV"
  info "Environment: $ENVIRONMENT (merged)"
else
  [[ -f ".env" ]] || error ".env file not found. Run: cp .env.example .env && nano .env"
  info "Environment: local (.env)"
fi

# Validate required variables are set and not placeholder values
check_var() {
  local val
  val=$(grep "^${1}=" "$ENV_FILE" | tail -1 | cut -d= -f2-)
  [[ -z "$val" ]]           && error "$1 is not set in $ENV_FILE"
  [[ "$val" == *change_me* ]] && error "$1 still has placeholder value. Edit $ENV_FILE"
  [[ "$val" == *PLACEHOLDER* ]] && error "$1 still has placeholder value. Edit $ENV_FILE"
}

check_var "POSTGRES_PASSWORD"
check_var "AWX_ADMIN_PASSWORD"
check_var "SECRET_KEY"

info "Environment validation: OK"

# ── Install Docker (if missing) ───────────────────────────────
section "Checking Docker Installation"

if ! systemctl is-active --quiet docker 2>/dev/null; then
  warn "Docker daemon not running. Starting..."
  systemctl start docker || error "Failed to start Docker daemon"
fi
info "Docker daemon: running"

# ── Pull images ───────────────────────────────────────────────
section "Pulling Docker Images"

info "Pulling latest images..."
docker compose --env-file "$ENV_FILE" pull
info "Images pulled."

# ── Deploy ────────────────────────────────────────────────────
section "Deploying AWX"

if [[ "$UPDATE" == "true" ]]; then
  info "Update mode: recreating containers with new images..."
  docker compose --env-file "$ENV_FILE" up -d --force-recreate --remove-orphans
else
  info "Starting services..."
  docker compose --env-file "$ENV_FILE" up -d --remove-orphans
fi

# ── Wait for PostgreSQL ───────────────────────────────────────
section "Waiting for PostgreSQL"

info "Waiting for PostgreSQL to be healthy..."
TIMEOUT=120
ELAPSED=0
until docker compose --env-file "$ENV_FILE" exec -T postgres \
  pg_isready -U "${POSTGRES_USER:-awx}" -d "${POSTGRES_DB:-awx}" &>/dev/null; do
  if [[ $ELAPSED -ge $TIMEOUT ]]; then
    error "PostgreSQL did not become healthy after ${TIMEOUT}s. Check: docker compose logs postgres"
  fi
  echo -n "."
  sleep 3
  ELAPSED=$((ELAPSED + 3))
done
echo ""
info "PostgreSQL is ready."

# ── Wait for AWX ──────────────────────────────────────────────
section "Waiting for AWX Web UI"

info "AWX is running migrations and starting up..."
info "This takes 3-5 minutes on first run."

TIMEOUT=300
ELAPSED=0
until curl -sf http://localhost/api/v2/ping/ &>/dev/null; do
  if [[ $ELAPSED -ge $TIMEOUT ]]; then
    warn "AWX did not respond after ${TIMEOUT}s."
    warn "Check logs: docker compose logs awx-web"
    break
  fi
  echo -n "."
  sleep 5
  ELAPSED=$((ELAPSED + 5))
done
echo ""

# ── Summary ───────────────────────────────────────────────────
section "Deployment Complete"

SERVER_IP=$(hostname -I | awk '{print $1}')
AWX_ADMIN_PASSWORD=$(grep "^AWX_ADMIN_PASSWORD=" "$ENV_FILE" | tail -1 | cut -d= -f2-)

info "Services running:"
docker compose --env-file "$ENV_FILE" ps

echo ""
info "╔══════════════════════════════════════════╗"
info "║           AWX is Ready!                  ║"
info "╠══════════════════════════════════════════╣"
info "║  URL:      http://${SERVER_IP}           "
info "║  Username: admin                         "
info "║  Password: ${AWX_ADMIN_PASSWORD}         "
info "╚══════════════════════════════════════════╝"
echo ""
info "Useful commands:"
info "  View logs:    docker compose logs -f"
info "  Status:       docker compose ps"
info "  Stop:         docker compose down"
info "  Health check: ./scripts/healthcheck.sh"
