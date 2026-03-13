#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo ""
echo -e "${RED}════════════════════════════════════${NC}"
echo -e "${RED}  AWX + Rancher Uninstall${NC}"
echo -e "${RED}════════════════════════════════════${NC}"
echo ""

# Parse flags
REMOVE_K3S=false
REMOVE_DATA=false

for arg in "$@"; do
  case $arg in
    --all)      REMOVE_K3S=true ;;
    --data)     REMOVE_DATA=true ;;
  esac
done

read -r -p "Are you sure you want to uninstall? [y/N] " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

# Remove AWX instance
info "Removing AWX instance..."
kubectl delete awx awx -n awx --ignore-not-found=true

# Remove AWX Operator
info "Removing AWX Operator..."
helm uninstall awx-operator -n awx 2>/dev/null || true

# Remove AWX namespace (and all PVCs)
if $REMOVE_DATA; then
  warn "Removing AWX namespace and all data..."
  kubectl delete namespace awx --ignore-not-found=true
else
  info "Keeping AWX data (PVCs). Use --data to remove."
fi

# Remove Rancher
info "Removing Rancher..."
helm uninstall rancher -n cattle-system 2>/dev/null || true
kubectl delete namespace cattle-system --ignore-not-found=true

# Remove cert-manager
info "Removing cert-manager..."
helm uninstall cert-manager -n cert-manager 2>/dev/null || true
kubectl delete namespace cert-manager --ignore-not-found=true

# Remove k3s
if $REMOVE_K3S; then
  warn "Removing k3s entirely..."
  /usr/local/bin/k3s-uninstall.sh 2>/dev/null || true
  rm -rf /etc/rancher /var/lib/rancher ~/.kube
  success "k3s removed"
else
  info "k3s kept. Use --all to remove k3s too."
fi

success "Uninstall complete"
