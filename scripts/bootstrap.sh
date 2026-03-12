#!/usr/bin/env bash
# scripts/bootstrap.sh
# ============================================================
# Bootstrap script for a fresh Ubuntu 22.04+ server.
# Installs: k3s (lightweight Kubernetes), kubectl, kustomize,
#           helm, and nginx-ingress controller.
# Run as root: sudo ./scripts/bootstrap.sh
# ============================================================
set -euo pipefail

# ── Colour output ─────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ── Require root ──────────────────────────────────────────────
[[ $EUID -eq 0 ]] || error "This script must be run as root (sudo)."

# ── Versions ──────────────────────────────────────────────────
K3S_VERSION="v1.29.4+k3s1"
KUSTOMIZE_VERSION="v5.3.0"
HELM_VERSION="v3.14.4"

info "=== AWX GitOps Bootstrap ==="
info "Ubuntu version: $(lsb_release -d | cut -f2)"

# ── System dependencies ───────────────────────────────────────
info "Installing system dependencies..."
apt-get update -qq
apt-get install -y -qq \
  curl wget git jq unzip apt-transport-https \
  ca-certificates gnupg lsb-release

# ── Install k3s (lightweight Kubernetes) ──────────────────────
if ! command -v k3s &>/dev/null; then
  info "Installing k3s ${K3S_VERSION}..."
  # k3s includes: kubectl, containerd, CoreDNS, Traefik (disabled), Flannel
  # We disable traefik and use nginx-ingress instead for better AWX compatibility
  curl -sfL https://get.k3s.io | \
    INSTALL_K3S_VERSION="${K3S_VERSION}" \
    sh -s - --disable=traefik \
            --write-kubeconfig-mode=644

  info "Waiting for k3s to be ready..."
  sleep 15
  k3s kubectl wait --for=condition=Ready node --all --timeout=120s
else
  info "k3s already installed: $(k3s --version | head -1)"
fi

# ── Configure kubectl ─────────────────────────────────────────
info "Configuring kubectl..."
mkdir -p "$HOME/.kube"
cp /etc/rancher/k3s/k3s.yaml "$HOME/.kube/config"
chmod 600 "$HOME/.kube/config"

# If running as root but want non-root user access:
if [[ -n "${SUDO_USER:-}" ]]; then
  USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
  mkdir -p "$USER_HOME/.kube"
  cp /etc/rancher/k3s/k3s.yaml "$USER_HOME/.kube/config"
  chmod 600 "$USER_HOME/.kube/config"
  chown "$SUDO_USER:$SUDO_USER" "$USER_HOME/.kube/config"
  info "kubectl configured for user: $SUDO_USER"
fi

# ── Install kustomize ─────────────────────────────────────────
if ! command -v kustomize &>/dev/null; then
  info "Installing kustomize ${KUSTOMIZE_VERSION}..."
  cd /tmp
  curl -sLO "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2F${KUSTOMIZE_VERSION}/kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz"
  tar -xzf "kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz"
  mv kustomize /usr/local/bin/kustomize
  chmod +x /usr/local/bin/kustomize
  cd -
  info "kustomize installed: $(kustomize version)"
else
  info "kustomize already installed: $(kustomize version)"
fi

# ── Install helm ──────────────────────────────────────────────
if ! command -v helm &>/dev/null; then
  info "Installing helm ${HELM_VERSION}..."
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | \
    DESIRED_VERSION="${HELM_VERSION}" bash
  info "helm installed: $(helm version --short)"
else
  info "helm already installed: $(helm version --short)"
fi

# ── Install nginx-ingress controller ─────────────────────────
info "Installing nginx-ingress controller..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx --force-update
helm repo update

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.replicaCount=1 \
  --wait --timeout=120s

info "nginx-ingress installed."

# ── Install cert-manager (for TLS) ───────────────────────────
info "Installing cert-manager..."
helm repo add jetstack https://charts.jetstack.io --force-update
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true \
  --wait --timeout=120s

info "cert-manager installed."

# ── Summary ───────────────────────────────────────────────────
info ""
info "=== Bootstrap Complete ==="
info "kubectl version:    $(kubectl version --client --short 2>/dev/null)"
info "kustomize version:  $(kustomize version)"
info "helm version:       $(helm version --short)"
info ""
info "Next steps:"
info "  1. cd into the repo root"
info "  2. cp k8s/base/secrets.env.example k8s/overlays/dev/secrets.env"
info "  3. Edit secrets.env with your passwords"
info "  4. ./scripts/deploy.sh dev"
