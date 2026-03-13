#!/bin/bash
set -euo pipefail
# ============================================================
#  Traefik Setup Script
#  Configures built-in k3s Traefik with:
#  - HTTPS + TLS 1.2+ strong ciphers
#  - HTTP → HTTPS redirect
#  - Security headers middleware
#  - Rate limiting
#  - Dashboard with basic auth
# ============================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
PUBLIC_IP=$(curl -s ifconfig.me)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRAEFIK_DIR="$(dirname "${SCRIPT_DIR}")/traefik"
NON_INTERACTIVE="${1:-}"

echo ""
echo -e "${CYAN}══════════════════════════════════════${NC}"
echo -e "${CYAN}  Traefik Setup — ${PUBLIC_IP}${NC}"
echo -e "${CYAN}══════════════════════════════════════${NC}"
echo ""

# ── Replace IP in all Traefik YAML files ────────────────────
info "Setting IP to ${PUBLIC_IP} in Traefik configs..."
find "${TRAEFIK_DIR}" -name "*.yaml" -exec sed -i "s/REPLACE_WITH_IP/${PUBLIC_IP}/g" {} \;
success "IP set"

# ── Dashboard basic auth ────────────────────────────────────
if [[ "${NON_INTERACTIVE}" == "--non-interactive" ]]; then
  # Default password in non-interactive mode
  DASH_PASS="Traefik@Admin123!"
  warn "Non-interactive mode: dashboard password = ${DASH_PASS}"
else
  echo ""
  read -r -s -p "Enter Traefik dashboard password (for https://traefik.${PUBLIC_IP}.nip.io): " DASH_PASS
  echo ""
fi

if ! command -v htpasswd &>/dev/null; then
  apt-get install -y apache2-utils -qq
fi

HASH=$(htpasswd -nb admin "${DASH_PASS}")
# Escape special chars for sed
HASH_ESCAPED=$(printf '%s\n' "${HASH}" | sed 's/[\/&]/\\&/g')
sed -i "s|admin:\$apr1\$REPLACE\$WithActualHashedPassword|${HASH_ESCAPED}|g" \
  "${TRAEFIK_DIR}/middleware/middleware.yaml"
success "Dashboard auth configured (user: admin)"

# ── Apply all Traefik configs ────────────────────────────────
info "Applying Traefik HelmChartConfig..."
kubectl apply -f "${TRAEFIK_DIR}/config/traefik-config.yaml"

info "Applying middleware..."
kubectl apply -f "${TRAEFIK_DIR}/middleware/middleware.yaml"

info "Applying IngressRoutes (AWX + Rancher + Dashboard)..."
kubectl apply -f "${TRAEFIK_DIR}/config/ingressroutes.yaml"
kubectl apply -f "${TRAEFIK_DIR}/dashboard/dashboard-ingress.yaml"

# ── Restart Traefik ─────────────────────────────────────────
info "Restarting Traefik to apply config..."
kubectl rollout restart deployment/traefik -n kube-system
kubectl rollout status deployment/traefik -n kube-system --timeout=60s
success "Traefik restarted"

# ── Verify ──────────────────────────────────────────────────
sleep 3
echo ""
info "Traefik service:"
kubectl get svc traefik -n kube-system
echo ""
info "Middleware:"
kubectl get middleware -n kube-system
echo ""

success "Traefik configured!"
echo ""
echo -e "  ${GREEN}Rancher:${NC}   https://${PUBLIC_IP}.nip.io"
echo -e "  ${GREEN}AWX:${NC}       https://awx.${PUBLIC_IP}.nip.io"
echo -e "  ${GREEN}Dashboard:${NC} https://traefik.${PUBLIC_IP}.nip.io/dashboard/"
echo -e "             login: admin / ${DASH_PASS}"
echo ""
warn "For Let's Encrypt (real domain): edit traefik/tls/letsencrypt.yaml then:"
warn "  kubectl apply -f traefik/tls/letsencrypt.yaml"
echo ""
