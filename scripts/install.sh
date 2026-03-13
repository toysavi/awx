#!/bin/bash
set -euo pipefail
# ============================================================
#  AWX on Rancher — Full Install Script
#  Stack: k3s + Traefik + cert-manager + Rancher + AWX Operator
#  OS: Ubuntu 24.04 LTS
# ============================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
banner()  { echo -e "\n${CYAN}══════════════════════════════════════\n  $*\n══════════════════════════════════════${NC}\n"; }

# ── Config ──────────────────────────────────────────────────
CERT_MANAGER_VERSION="v1.14.4"
AWX_VERSION="${AWX_VERSION:-24.6.1}"
BOOTSTRAP_PASSWORD="${BOOTSTRAP_PASSWORD:-admin}"
AWX_ADMIN_EMAIL="${AWX_ADMIN_EMAIL:-admin@example.com}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "${SCRIPT_DIR}")"

# ── Checks ──────────────────────────────────────────────────
banner "Pre-flight Checks"
[[ $EUID -ne 0 ]] && error "Run as root: sudo bash $0"

PUBLIC_IP=$(curl -s ifconfig.me)
info "Public IP:   ${PUBLIC_IP}"
info "AWX version: ${AWX_VERSION}"
info "Repo dir:    ${REPO_DIR}"

# ── System ──────────────────────────────────────────────────
banner "System Preparation"
apt-get update -qq
apt-get install -y curl wget git openssl python3 python3-pip apache2-utils --no-install-recommends
sysctl -w vm.overcommit_memory=1
grep -qxF 'vm.overcommit_memory = 1' /etc/sysctl.conf || echo 'vm.overcommit_memory = 1' >> /etc/sysctl.conf
success "System ready"

# ── k3s ─────────────────────────────────────────────────────
banner "Installing k3s"
if command -v k3s &>/dev/null; then
  warn "k3s already installed: $(k3s --version | head -1)"
else
  curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --write-kubeconfig-mode=644" sh -
  success "k3s installed"
fi

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
grep -qxF 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' ~/.bashrc || \
  echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> ~/.bashrc
echo 'KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> /etc/environment

info "Waiting for node to be ready..."
kubectl wait --for=condition=Ready node --all --timeout=120s
success "k3s node ready: $(kubectl get nodes --no-headers | awk '{print $1, $2}')"

# ── Helm ────────────────────────────────────────────────────
banner "Installing Helm"
if command -v helm &>/dev/null; then
  warn "Helm already installed: $(helm version --short)"
else
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  success "Helm installed"
fi

# ── cert-manager ────────────────────────────────────────────
banner "Installing cert-manager ${CERT_MANAGER_VERSION}"
if kubectl get ns cert-manager &>/dev/null; then
  warn "cert-manager already installed"
else
  kubectl apply -f "https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.crds.yaml"
  helm repo add jetstack https://charts.jetstack.io --force-update
  helm repo update
  helm install cert-manager jetstack/cert-manager \
    --namespace cert-manager --create-namespace \
    --version "${CERT_MANAGER_VERSION}"
  kubectl wait --for=condition=Ready pods --all -n cert-manager --timeout=120s
  success "cert-manager installed"
fi

# ── Rancher ─────────────────────────────────────────────────
banner "Installing Rancher"
if helm status rancher -n cattle-system &>/dev/null; then
  warn "Rancher already installed"
else
  helm repo add rancher-stable https://releases.rancher.com/server-charts/stable --force-update
  helm repo update
  helm install rancher rancher-stable/rancher \
    --namespace cattle-system --create-namespace \
    --set hostname="${PUBLIC_IP}.nip.io" \
    --set bootstrapPassword="${BOOTSTRAP_PASSWORD}" \
    --set ingress.tls.source=rancher \
    --set replicas=1
  info "Waiting for Rancher (3-5 minutes)..."
  kubectl rollout status deployment/rancher -n cattle-system --timeout=300s
  success "Rancher installed"
fi

# ── Traefik ─────────────────────────────────────────────────
banner "Configuring Traefik"
bash "${SCRIPT_DIR}/setup-traefik.sh" --non-interactive
success "Traefik configured"

# ── AWX Operator ────────────────────────────────────────────
banner "Installing AWX Operator"
if helm status awx-operator -n awx &>/dev/null; then
  warn "AWX Operator already installed"
else
  helm repo add awx-operator https://ansible-community.github.io/awx-operator-helm/ --force-update
  helm repo update
  helm install awx-operator awx-operator/awx-operator \
    --namespace awx --create-namespace \
    -f "${REPO_DIR}/k8s/operator/values.yaml"
  kubectl wait --for=condition=Ready pods --all -n awx --timeout=120s
  success "AWX Operator installed"
fi

# ── AWX Instance ────────────────────────────────────────────
banner "Deploying AWX Instance v${AWX_VERSION}"
if kubectl get awx awx -n awx &>/dev/null; then
  warn "AWX instance already exists"
else
  sed "s/REPLACE_WITH_IP/${PUBLIC_IP}/g" "${REPO_DIR}/k8s/awx/awx-instance.yaml" | kubectl apply -f -
  info "Waiting for AWX web pod (5-10 minutes)..."
  kubectl wait --for=condition=Ready pods \
    -l app.kubernetes.io/name=awx-web \
    -n awx --timeout=600s || warn "Timeout — AWX may still be initializing"
  success "AWX instance deployed"
fi

# ── Summary ─────────────────────────────────────────────────
banner "Installation Complete ✓"
AWX_PASS=$(kubectl get secret awx-admin-password -n awx \
  -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "(still initializing)")

echo ""
echo -e "  ${GREEN}Rancher:${NC}            https://${PUBLIC_IP}.nip.io"
echo -e "  ${GREEN}AWX:${NC}                https://awx.${PUBLIC_IP}.nip.io"
echo -e "  ${GREEN}Traefik Dashboard:${NC}  https://traefik.${PUBLIC_IP}.nip.io/dashboard/"
echo ""
echo -e "  ${GREEN}Rancher login:${NC}  admin / ${BOOTSTRAP_PASSWORD}"
echo -e "  ${GREEN}AWX login:${NC}      admin / ${AWX_PASS}"
echo ""
echo -e "  ${YELLOW}Note: Accept self-signed cert warning in browser${NC}"
echo -e "  ${YELLOW}Run './scripts/healthcheck.sh' to verify all services${NC}"
echo ""
