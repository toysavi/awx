#!/bin/bash
set -euo pipefail
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }

REMOVE_K3S=false
REMOVE_DATA=false
for arg in "$@"; do
  case $arg in
    --all)  REMOVE_K3S=true ;;
    --data) REMOVE_DATA=true ;;
  esac
done

echo -e "\n${RED}════════════════════════════════════\n  AWX + Rancher Uninstall\n════════════════════════════════════${NC}\n"
warn "This will remove: AWX, Rancher, cert-manager"
$REMOVE_DATA && warn "This will also remove ALL AWX data (PVCs)"
$REMOVE_K3S  && warn "This will also remove k3s entirely"
echo ""
read -r -p "Continue? [y/N] " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

info "Removing AWX instance..."
kubectl delete awx awx -n awx --ignore-not-found=true

info "Removing AWX Operator..."
helm uninstall awx-operator -n awx 2>/dev/null || true

if $REMOVE_DATA; then
  warn "Removing AWX namespace and all data..."
  kubectl delete namespace awx --ignore-not-found=true
fi

info "Removing Rancher..."
helm uninstall rancher -n cattle-system 2>/dev/null || true
kubectl delete namespace cattle-system --ignore-not-found=true

info "Removing cert-manager..."
helm uninstall cert-manager -n cert-manager 2>/dev/null || true
kubectl delete namespace cert-manager --ignore-not-found=true

if $REMOVE_K3S; then
  warn "Removing k3s..."
  /usr/local/bin/k3s-uninstall.sh 2>/dev/null || true
  rm -rf /etc/rancher /var/lib/rancher ~/.kube
  success "k3s removed"
else
  info "k3s kept. Use --all to remove k3s entirely."
fi

success "Uninstall complete"
