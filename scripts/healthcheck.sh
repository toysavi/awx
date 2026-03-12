#!/usr/bin/env bash
# scripts/healthcheck.sh
# ============================================================
# Post-deployment health check for AWX.
# Verifies pods, services, and AWX API responsiveness.
# ============================================================
set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
pass()  { echo -e "${GREEN}[PASS]${NC} $*"; }
fail()  { echo -e "${RED}[FAIL]${NC} $*"; FAILED=1; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
info()  { echo "[INFO] $*"; }

ENVIRONMENT="${1:-dev}"
NAMESPACE="awx-${ENVIRONMENT}"
FAILED=0

echo ""
echo "═══════════════════════════════════════"
echo "  AWX Health Check — ${ENVIRONMENT}"
echo "  Namespace: ${NAMESPACE}"
echo "═══════════════════════════════════════"
echo ""

# ── Check namespace ───────────────────────────────────────────
if kubectl get namespace "$NAMESPACE" &>/dev/null; then
  pass "Namespace '$NAMESPACE' exists"
else
  fail "Namespace '$NAMESPACE' does not exist"
fi

# ── Check PostgreSQL ──────────────────────────────────────────
info "Checking PostgreSQL..."
PG_READY=$(kubectl get pods -n "$NAMESPACE" \
  -l app=awx-postgres \
  -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null || echo "false")

if [[ "$PG_READY" == "true" ]]; then
  pass "PostgreSQL pod is ready"
else
  fail "PostgreSQL pod is not ready"
  kubectl get pods -n "$NAMESPACE" -l app=awx-postgres 2>/dev/null || true
fi

# ── Check AWX pods ────────────────────────────────────────────
info "Checking AWX pods..."
AWX_PODS=$(kubectl get pods -n "$NAMESPACE" \
  -l app.kubernetes.io/name=awx \
  --field-selector=status.phase=Running \
  -o name 2>/dev/null | wc -l)

if [[ "$AWX_PODS" -ge 1 ]]; then
  pass "AWX pods running: $AWX_PODS"
else
  fail "No AWX pods running in namespace $NAMESPACE"
  kubectl get pods -n "$NAMESPACE" 2>/dev/null || true
fi

# ── Check AWX service ─────────────────────────────────────────
info "Checking AWX service..."
if kubectl get svc awx-service -n "$NAMESPACE" &>/dev/null; then
  pass "AWX service 'awx-service' exists"
else
  fail "AWX service 'awx-service' not found"
fi

# ── Check secrets ─────────────────────────────────────────────
info "Checking secrets..."
for secret in awx-postgres-secret awx-postgres-configuration awx-admin-password; do
  if kubectl get secret "$secret" -n "$NAMESPACE" &>/dev/null; then
    pass "Secret '$secret' exists"
  else
    fail "Secret '$secret' not found"
  fi
done

# ── Check AWX API via port-forward ────────────────────────────
info "Testing AWX API (via temporary port-forward)..."

# Start port-forward in background
kubectl port-forward svc/awx-service -n "$NAMESPACE" 18080:80 &>/dev/null &
PF_PID=$!
trap "kill $PF_PID 2>/dev/null || true" EXIT
sleep 3

AWX_HTTP=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:18080/api/v2/ping/ 2>/dev/null || echo "000")

if [[ "$AWX_HTTP" == "200" ]]; then
  pass "AWX API /api/v2/ping/ responded: HTTP $AWX_HTTP"
elif [[ "$AWX_HTTP" == "301" || "$AWX_HTTP" == "302" ]]; then
  pass "AWX API /api/v2/ping/ redirect: HTTP $AWX_HTTP (normal for HTTPS redirect)"
else
  warn "AWX API returned HTTP $AWX_HTTP — AWX may still be initializing"
fi

kill $PF_PID 2>/dev/null || true

# ── Summary ───────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════"
if [[ "$FAILED" -eq 0 ]]; then
  echo -e "${GREEN}  All checks passed ✓${NC}"
else
  echo -e "${RED}  Some checks failed ✗${NC}"
  echo "  Review the [FAIL] items above."
fi
echo "═══════════════════════════════════════"
echo ""

# Print admin password
ADMIN_PASS=$(kubectl get secret awx-admin-password -n "$NAMESPACE" \
  -o jsonpath='{.data.password}' 2>/dev/null | base64 -d 2>/dev/null || echo "N/A")
info "Admin password: $ADMIN_PASS"
info "Port-forward:   kubectl port-forward svc/awx-service -n $NAMESPACE 8080:80"
info "Open:           http://localhost:8080 (user: admin)"

exit $FAILED
