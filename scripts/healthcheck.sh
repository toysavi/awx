#!/bin/bash
set -euo pipefail
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
ok()   { echo -e "  ${GREEN}[OK]${NC}    $*"; }
fail() { echo -e "  ${RED}[FAIL]${NC}  $*"; FAILED=1; }
warn() { echo -e "  ${YELLOW}[WARN]${NC}  $*"; }
FAILED=0

PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "unknown")

echo ""
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo -e "${CYAN}   AWX on Rancher — Health Check${NC}"
echo -e "${CYAN}═══════════════════════════════════════════${NC}"

# ── k3s ─────────────────────────────────────────────────────
echo -e "\n${CYAN}--- k3s Node ---${NC}"
NODE=$(kubectl get nodes --no-headers 2>/dev/null | awk '{print $1,$2}' | head -1)
if echo "${NODE}" | grep -q "Ready"; then
  ok "Node: ${NODE}"
else
  fail "Node: ${NODE:-unreachable}"
fi

# ── Traefik ─────────────────────────────────────────────────
echo -e "\n${CYAN}--- Traefik ---${NC}"
TRAEFIK=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik --no-headers 2>/dev/null | awk '{print $3}' | head -1)
[[ "$TRAEFIK" == "Running" ]] && ok "Pod: Running" || fail "Pod: ${TRAEFIK:-not found}"

TRAEFIK_SVC=$(kubectl get svc traefik -n kube-system --no-headers 2>/dev/null | awk '{print $4}')
if [[ "${TRAEFIK_SVC}" == "<pending>" ]]; then
  warn "LoadBalancer IP: pending"
else
  ok "LoadBalancer IP: ${TRAEFIK_SVC}"
fi

HTTP=$(curl -sk -o /dev/null -w "%{http_code}" "http://${PUBLIC_IP}" 2>/dev/null || echo "000")
[[ "$HTTP" =~ ^(200|301|302)$ ]] && ok "HTTP port 80: ${HTTP}" || warn "HTTP port 80: ${HTTP}"

HTTPS=$(curl -sk -o /dev/null -w "%{http_code}" "https://${PUBLIC_IP}" 2>/dev/null || echo "000")
[[ "$HTTPS" =~ ^(200|301|302)$ ]] && ok "HTTPS port 443: ${HTTPS}" || warn "HTTPS port 443: ${HTTPS}"

# ── cert-manager ────────────────────────────────────────────
echo -e "\n${CYAN}--- cert-manager ---${NC}"
CM=$(kubectl get pods -n cert-manager --no-headers 2>/dev/null | grep -c "Running" || echo 0)
[[ "$CM" -ge 3 ]] && ok "${CM}/3 pods running" || fail "Only ${CM}/3 pods running"

# ── Rancher ─────────────────────────────────────────────────
echo -e "\n${CYAN}--- Rancher ---${NC}"
RANCHER=$(kubectl get pods -n cattle-system -l app=rancher --no-headers 2>/dev/null | awk '{print $3}' | head -1)
[[ "$RANCHER" == "Running" ]] && ok "Pod: Running" || fail "Pod: ${RANCHER:-not found}"

RANCHER_HTTP=$(curl -sk -o /dev/null -w "%{http_code}" "https://${PUBLIC_IP}.nip.io/ping" 2>/dev/null || echo "000")
[[ "$RANCHER_HTTP" == "200" ]] && ok "API ping: HTTP ${RANCHER_HTTP}" || warn "API ping: HTTP ${RANCHER_HTTP}"

# ── AWX Operator ────────────────────────────────────────────
echo -e "\n${CYAN}--- AWX Operator ---${NC}"
OPERATOR=$(kubectl get pods -n awx -l control-plane=controller-manager --no-headers 2>/dev/null | awk '{print $3}' | head -1)
[[ "$OPERATOR" == "Running" ]] && ok "Pod: Running" || fail "Pod: ${OPERATOR:-not found}"

# ── AWX Pods ────────────────────────────────────────────────
echo -e "\n${CYAN}--- AWX Pods ---${NC}"
for label in awx-web awx-task awx-postgres; do
  STATUS=$(kubectl get pods -n awx -l "app.kubernetes.io/name=${label}" --no-headers 2>/dev/null | awk '{print $2,$3}' | head -1)
  if echo "${STATUS}" | grep -q "Running"; then
    ok "${label}: ${STATUS}"
  else
    fail "${label}: ${STATUS:-not found}"
  fi
done

# ── AWX API ─────────────────────────────────────────────────
echo -e "\n${CYAN}--- AWX API ---${NC}"
AWX_HTTP=$(curl -sk -o /dev/null -w "%{http_code}" "https://awx.${PUBLIC_IP}.nip.io/api/v2/ping/" 2>/dev/null || echo "000")
[[ "$AWX_HTTP" == "200" ]] && ok "API ping: HTTP ${AWX_HTTP}" || warn "API ping: HTTP ${AWX_HTTP} (may still be starting)"

# ── Credentials ─────────────────────────────────────────────
echo -e "\n${CYAN}--- Credentials ---${NC}"
AWX_PASS=$(kubectl get secret awx-admin-password -n awx \
  -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "not available yet")
ok "AWX admin password: ${AWX_PASS}"

# ── Summary ─────────────────────────────────────────────────
echo ""
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
if [[ $FAILED -eq 0 ]]; then
  echo -e "  ${GREEN}All checks passed ✓${NC}"
else
  echo -e "  ${RED}Some checks failed ✗ — see above${NC}"
fi
echo ""
echo -e "  Rancher:   https://${PUBLIC_IP}.nip.io"
echo -e "  AWX:       https://awx.${PUBLIC_IP}.nip.io"
echo -e "  Dashboard: https://traefik.${PUBLIC_IP}.nip.io/dashboard/"
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo ""
exit $FAILED
