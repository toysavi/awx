#!/bin/bash
set -euo pipefail

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

ok()   { echo -e "  ${GREEN}[OK]${NC}    $*"; }
fail() { echo -e "  ${RED}[FAIL]${NC}  $*"; FAILED=1; }
warn() { echo -e "  ${YELLOW}[WARN]${NC}  $*"; }
FAILED=0

PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "unknown")

echo ""
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${CYAN}        AWX + Rancher Health Check${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo ""

# ── k3s node ────────────────────────────────────────────────
echo "--- k3s Node ---"
NODE_STATUS=$(kubectl get nodes --no-headers 2>/dev/null | awk '{print $2}' | head -1)
if [[ "$NODE_STATUS" == "Ready" ]]; then
  ok "Node: Ready"
else
  fail "Node: ${NODE_STATUS:-unreachable}"
fi

# ── Traefik ─────────────────────────────────────────────────
echo ""
echo "--- Traefik Ingress ---"
TRAEFIK_STATUS=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik \
  --no-headers 2>/dev/null | awk '{print $3}' | head -1)
if [[ "$TRAEFIK_STATUS" == "Running" ]]; then
  ok "Traefik: Running"
else
  fail "Traefik: ${TRAEFIK_STATUS:-not found}"
fi

# ── cert-manager ────────────────────────────────────────────
echo ""
echo "--- cert-manager ---"
CM_READY=$(kubectl get pods -n cert-manager --no-headers 2>/dev/null | grep -c "Running" || true)
if [[ "$CM_READY" -ge 3 ]]; then
  ok "cert-manager: ${CM_READY} pods running"
else
  fail "cert-manager: only ${CM_READY} pods running (expected 3)"
fi

# ── Rancher ─────────────────────────────────────────────────
echo ""
echo "--- Rancher ---"
RANCHER_STATUS=$(kubectl get pods -n cattle-system -l app=rancher \
  --no-headers 2>/dev/null | awk '{print $3}' | head -1)
if [[ "$RANCHER_STATUS" == "Running" ]]; then
  ok "Rancher pod: Running"
else
  fail "Rancher pod: ${RANCHER_STATUS:-not found}"
fi

HTTP_CODE=$(curl -sk -o /dev/null -w "%{http_code}" \
  "https://${PUBLIC_IP}.nip.io/ping" 2>/dev/null || echo "000")
if [[ "$HTTP_CODE" == "200" ]]; then
  ok "Rancher API: HTTP ${HTTP_CODE}"
else
  warn "Rancher API: HTTP ${HTTP_CODE} (may still be starting)"
fi

# ── AWX Operator ────────────────────────────────────────────
echo ""
echo "--- AWX Operator ---"
OPERATOR_STATUS=$(kubectl get pods -n awx -l control-plane=controller-manager \
  --no-headers 2>/dev/null | awk '{print $3}' | head -1)
if [[ "$OPERATOR_STATUS" == "Running" ]]; then
  ok "AWX Operator: Running"
else
  fail "AWX Operator: ${OPERATOR_STATUS:-not found}"
fi

# ── AWX Pods ────────────────────────────────────────────────
echo ""
echo "--- AWX Pods ---"
for label in "awx-web" "awx-task" "awx-postgres"; do
  POD_STATUS=$(kubectl get pods -n awx -l "app.kubernetes.io/name=${label}" \
    --no-headers 2>/dev/null | awk '{print $3}' | head -1)
  if [[ "$POD_STATUS" == "Running" ]]; then
    ok "${label}: Running"
  else
    fail "${label}: ${POD_STATUS:-not found}"
  fi
done

# ── AWX API ─────────────────────────────────────────────────
echo ""
echo "--- AWX API ---"
AWX_HTTP=$(curl -sk -o /dev/null -w "%{http_code}" \
  "https://awx.${PUBLIC_IP}.nip.io/api/v2/ping/" 2>/dev/null || echo "000")
if [[ "$AWX_HTTP" == "200" ]]; then
  ok "AWX API: HTTP ${AWX_HTTP}"
else
  warn "AWX API: HTTP ${AWX_HTTP} (may still be starting)"
fi

# ── Admin password ──────────────────────────────────────────
echo ""
echo "--- Credentials ---"
AWX_PASS=$(kubectl get secret awx-admin-password -n awx \
  -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "not available yet")
ok "AWX admin password: ${AWX_PASS}"

# ── Summary ─────────────────────────────────────────────────
echo ""
echo -e "${CYAN}═══════════════════════════════════════${NC}"
if [[ $FAILED -eq 0 ]]; then
  echo -e "  ${GREEN}All checks passed ✓${NC}"
else
  echo -e "  ${RED}Some checks failed ✗${NC}"
fi
echo ""
echo -e "  Rancher: https://${PUBLIC_IP}.nip.io"
echo -e "  AWX:     https://awx.${PUBLIC_IP}.nip.io"
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo ""
