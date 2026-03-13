#!/usr/bin/env bash
# scripts/healthcheck.sh
# ============================================================
# Post-deployment health check for AWX Docker Compose.
# ============================================================
set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
pass()  { echo -e "${GREEN}[PASS]${NC} $*"; }
fail()  { echo -e "${RED}[FAIL]${NC} $*"; FAILED=1; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"
FAILED=0

echo ""
echo "═══════════════════════════════════════"
echo "        AWX Health Check"
echo "═══════════════════════════════════════"
echo ""

# ── Check Docker services ─────────────────────────────────────
echo "--- Docker Services ---"
for svc in postgres redis awx-web awx-task; do
  STATUS=$(docker compose ps "$svc" --format "{{.Status}}" 2>/dev/null || echo "not found")
  if echo "$STATUS" | grep -q "Up\|running\|healthy"; then
    pass "$svc: $STATUS"
  else
    fail "$svc: $STATUS"
  fi
done

# ── Check PostgreSQL ──────────────────────────────────────────
echo ""
echo "--- PostgreSQL ---"
if docker compose exec -T postgres pg_isready -U awx -d awx &>/dev/null; then
  pass "PostgreSQL accepting connections"

  # Check AWX tables exist (migrations ran)
  TABLE_COUNT=$(docker compose exec -T postgres \
    psql -U awx -d awx -tAc \
    "SELECT count(*) FROM information_schema.tables WHERE table_schema='public';" \
    2>/dev/null || echo "0")

  if [[ "$TABLE_COUNT" -gt 10 ]]; then
    pass "Database tables: $TABLE_COUNT (migrations complete)"
  else
    warn "Database tables: $TABLE_COUNT (migrations may still be running)"
  fi
else
  fail "PostgreSQL not responding"
fi

# ── Check Redis ───────────────────────────────────────────────
echo ""
echo "--- Redis ---"
if docker compose exec -T redis redis-cli ping 2>/dev/null | grep -q "PONG"; then
  pass "Redis responding"
else
  fail "Redis not responding"
fi

# ── Check AWX API ─────────────────────────────────────────────
echo ""
echo "--- AWX API ---"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/api/v2/ping/ 2>/dev/null || echo "000")
if [[ "$HTTP_CODE" == "200" ]]; then
  pass "AWX API /api/v2/ping/ → HTTP $HTTP_CODE"
elif [[ "$HTTP_CODE" == "301" || "$HTTP_CODE" == "302" ]]; then
  pass "AWX API redirect → HTTP $HTTP_CODE (normal with HTTPS)"
else
  fail "AWX API → HTTP $HTTP_CODE (may still be starting)"
fi

# ── Check AWX admin login ─────────────────────────────────────
AWX_ADMIN_PASSWORD=$(grep "^AWX_ADMIN_PASSWORD=" .env 2>/dev/null | cut -d= -f2- || echo "")
if [[ -n "$AWX_ADMIN_PASSWORD" ]]; then
  AUTH_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -u "admin:${AWX_ADMIN_PASSWORD}" \
    http://localhost/api/v2/me/ 2>/dev/null || echo "000")
  if [[ "$AUTH_CODE" == "200" ]]; then
    pass "Admin login: OK (HTTP $AUTH_CODE)"
  else
    warn "Admin login: HTTP $AUTH_CODE (AWX may still be initializing)"
  fi
fi

# ── Resource usage ────────────────────────────────────────────
echo ""
echo "--- Resource Usage ---"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" \
  awx-postgres awx-redis awx-web awx-task 2>/dev/null || true

# ── Summary ───────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════"
if [[ "$FAILED" -eq 0 ]]; then
  echo -e "${GREEN}  All checks passed ✓${NC}"
else
  echo -e "${RED}  Some checks failed ✗ — see above${NC}"
fi
echo "═══════════════════════════════════════"

SERVER_IP=$(hostname -I | awk '{print $1}')
echo ""
echo "  URL:      http://${SERVER_IP}"
echo "  Username: admin"
echo "  Logs:     docker compose logs -f awx-web"
echo ""

exit $FAILED
