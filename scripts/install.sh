#!/bin/bash
set -euo pipefail

# ============================================================
#  AWX on Rancher — Full Install Script
#  Tested on: Ubuntu 24.04 LTS + Azure VM
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

banner() {
  echo ""
  echo -e "${CYAN}══════════════════════════════════════${NC}"
  echo -e "${CYAN}  $*${NC}"
  echo -e "${CYAN}══════════════════════════════════════${NC}"
  echo ""
}

# ── Config ──────────────────────────────────────────────────
CERT_MANAGER_VERSION="v1.14.4"
AWX_VERSION="24.6.1"
BOOTSTRAP_PASSWORD="${BOOTSTRAP_PASSWORD:-admin}"
AWX_ADMIN_EMAIL="${AWX_ADMIN_EMAIL:-admin@example.com}"
PUBLIC_IP=$(curl -s ifconfig.me)

# ── Checks ──────────────────────────────────────────────────
banner "Pre-flight Checks"

[[ $EUID -ne 0 ]] && error "Run as root: sudo bash $0"
info "Public IP: ${PUBLIC_IP}"
info "AWX version: ${AWX_VERSION}"

# ── System packages ─────────────────────────────────────────
banner "System Packages"

apt-get update -qq
apt-get install -y curl wget git openssl python3 python3-pip --no-install-recommends
success "Packages installed"

# ── k3s ─────────────────────────────────────────────────────
banner "Installing k3s"

if command -v k3s &>/dev/null; then
  warn "k3s already installed, skipping"
else
  curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --write-kubeconfig-mode=644" sh -
  success "k3s installed"
fi

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
grep -qxF 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' ~/.bashrc || \
  echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> ~/.bashrc

# Wait for node ready
info "Waiting for k3s node to be ready..."
kubectl wait --for=condition=Ready node --all --timeout=120s
success "k3s node ready"

# ── Helm ────────────────────────────────────────────────────
banner "Installing Helm"

if command -v helm &>/dev/null; then
  warn "Helm already installed: $(helm version --short)"
else
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  success "Helm installed"
fi

# ── cert-manager ────────────────────────────────────────────
banner "Installing cert-manager"

if kubectl get namespace cert-manager &>/dev/null; then
  warn "cert-manager namespace exists, skipping"
else
  kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.crds.yaml

  helm repo add jetstack https://charts.jetstack.io --force-update
  helm repo update

  helm install cert-manager jetstack/cert-manager \
    --namespace cert-manager \
    --create-namespace \
    --version ${CERT_MANAGER_VERSION}

  kubectl wait --for=condition=Ready pods --all -n cert-manager --timeout=120s
  success "cert-manager installed"
fi

# ── Rancher ─────────────────────────────────────────────────
banner "Installing Rancher"

if helm status rancher -n cattle-system &>/dev/null; then
  warn "Rancher already installed, skipping"
else
  helm repo add rancher-stable https://releases.rancher.com/server-charts/stable --force-update
  helm repo update

  helm install rancher rancher-stable/rancher \
    --namespace cattle-system \
    --create-namespace \
    --set hostname=${PUBLIC_IP}.nip.io \
    --set bootstrapPassword=${BOOTSTRAP_PASSWORD} \
    --set ingress.tls.source=rancher \
    --set replicas=1

  info "Waiting for Rancher rollout (this may take 3-5 minutes)..."
  kubectl rollout status deployment/rancher -n cattle-system --timeout=300s
  success "Rancher installed"
fi

# ── AWX Operator ────────────────────────────────────────────
banner "Installing AWX Operator"

if helm status awx-operator -n awx &>/dev/null; then
  warn "AWX Operator already installed, skipping"
else
  helm repo add awx-operator https://ansible-community.github.io/awx-operator-helm/ --force-update
  helm repo update

  helm install awx-operator awx-operator/awx-operator \
    --namespace awx \
    --create-namespace

  info "Waiting for AWX Operator to be ready..."
  kubectl wait --for=condition=Ready pods --all -n awx --timeout=120s
  success "AWX Operator installed"
fi

# ── AWX Instance ────────────────────────────────────────────
banner "Deploying AWX Instance"

if kubectl get awx awx -n awx &>/dev/null; then
  warn "AWX instance already exists, skipping"
else
  cat <<EOF | kubectl apply -f -
apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: awx
  namespace: awx
spec:
  service_type: ClusterIP
  ingress_type: ingress
  ingress_class_name: traefik
  hostname: awx.${PUBLIC_IP}.nip.io
  admin_user: admin
  admin_email: ${AWX_ADMIN_EMAIL}
  postgres_storage_class: local-path
  projects_storage_class: local-path
  projects_storage_size: 8Gi
  web_resource_requirements:
    requests:
      memory: 512Mi
      cpu: 500m
    limits:
      memory: 2Gi
      cpu: 2000m
  task_resource_requirements:
    requests:
      memory: 512Mi
      cpu: 500m
    limits:
      memory: 2Gi
      cpu: 2000m
EOF

  info "Waiting for AWX pods (this may take 5-10 minutes)..."
  sleep 10
  kubectl wait --for=condition=Ready pods \
    -l app.kubernetes.io/name=awx-web \
    -n awx --timeout=600s || true

  success "AWX instance deployed"
fi

# ── Summary ─────────────────────────────────────────────────
banner "Installation Complete"

AWX_PASSWORD=$(kubectl get secret awx-admin-password -n awx \
  -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "still initializing...")

echo ""
echo -e "${GREEN}  Rancher UI:${NC}  https://${PUBLIC_IP}.nip.io"
echo -e "${GREEN}  AWX UI:${NC}      https://awx.${PUBLIC_IP}.nip.io"
echo ""
echo -e "${GREEN}  Rancher login:${NC}  admin / ${BOOTSTRAP_PASSWORD}"
echo -e "${GREEN}  AWX login:${NC}     admin / ${AWX_PASSWORD}"
echo ""
echo -e "${YELLOW}  Note: Accept self-signed certificate warning in browser${NC}"
echo ""
