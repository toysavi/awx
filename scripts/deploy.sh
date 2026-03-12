#!/usr/bin/env bash
# scripts/deploy.sh
# ============================================================
# Main deployment script for AWX GitOps.
# Usage:
#   ./scripts/deploy.sh <environment> [--dry-run]
#   ./scripts/deploy.sh dev
#   ./scripts/deploy.sh staging
#   ./scripts/deploy.sh prod --dry-run
# ============================================================
set -euo pipefail

# ── Colour output ─────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}    $*"; }
error()   { echo -e "${RED}[ERROR]${NC}   $*" >&2; exit 1; }
section() { echo -e "\n${BLUE}══════════════════════════════════${NC}"; echo -e "${BLUE}  $*${NC}"; echo -e "${BLUE}══════════════════════════════════${NC}"; }

# ── Arguments ─────────────────────────────────────────────────
ENVIRONMENT="${1:-}"
DRY_RUN="${2:-}"

[[ -z "$ENVIRONMENT" ]] && error "Usage: $0 <dev|staging|prod> [--dry-run]"
[[ "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]] || error "Environment must be: dev, staging, or prod"

NAMESPACE="awx-${ENVIRONMENT}"
OVERLAY_DIR="k8s/overlays/${ENVIRONMENT}"
OPERATOR_DIR="k8s/operator"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# ── Pre-flight checks ─────────────────────────────────────────
section "Pre-flight Checks"

command -v kubectl    &>/dev/null || error "kubectl not found. Run scripts/bootstrap.sh first."
command -v kustomize  &>/dev/null || error "kustomize not found. Run scripts/bootstrap.sh first."

# Check cluster connectivity
kubectl cluster-info &>/dev/null || error "Cannot connect to Kubernetes cluster. Check your kubeconfig."
info "Cluster connection: OK"

# Check overlay directory exists
[[ -d "$REPO_ROOT/$OVERLAY_DIR" ]] || error "Overlay directory not found: $OVERLAY_DIR"

# Check secrets file exists (not needed in CI where secrets are pre-created)
SECRETS_FILE="$REPO_ROOT/$OVERLAY_DIR/secrets.env"
if [[ ! -f "$SECRETS_FILE" ]]; then
  warn "secrets.env not found at $SECRETS_FILE"
  warn "If running in CI/CD, secrets should already be created as Kubernetes Secrets."
  warn "For local deploy: cp k8s/base/secrets.env.example $SECRETS_FILE && edit it"
  # Don't fail — CI creates secrets separately via generate-secrets.sh
fi

# ── Validate manifests (dry-run) ──────────────────────────────
section "Validating Manifests"

info "Running kustomize build for $ENVIRONMENT..."
if ! kustomize build "$REPO_ROOT/$OVERLAY_DIR" > /tmp/awx-manifest-${ENVIRONMENT}.yaml 2>&1; then
  error "kustomize build failed. Check your manifests."
fi
info "kustomize build: OK ($(wc -l < /tmp/awx-manifest-${ENVIRONMENT}.yaml) lines)"

if [[ "$DRY_RUN" == "--dry-run" ]]; then
  info "Dry-run mode: applying manifests with --dry-run=client..."
  kubectl apply --dry-run=client -f /tmp/awx-manifest-${ENVIRONMENT}.yaml
  info "Dry-run complete. No changes applied."
  exit 0
fi

# ── Deploy AWX Operator ───────────────────────────────────────
section "Deploying AWX Operator"

info "Installing AWX Operator..."
kustomize build "$REPO_ROOT/$OPERATOR_DIR" | kubectl apply -f -

info "Waiting for AWX Operator to be ready (up to 3 minutes)..."
kubectl wait deployment \
  --selector=app.kubernetes.io/name=awx-operator \
  --for=condition=Available \
  --namespace=awx-operator-system \
  --timeout=180s || warn "Operator deployment timeout — continuing anyway, it may still be initialising."

# ── Deploy AWX (PostgreSQL + AWX instance) ────────────────────
section "Deploying AWX to '$ENVIRONMENT'"

info "Applying kustomize overlay: $OVERLAY_DIR"
kustomize build "$REPO_ROOT/$OVERLAY_DIR" | kubectl apply -f -

info "Namespace created: $NAMESPACE"

# ── Wait for PostgreSQL ───────────────────────────────────────
section "Waiting for PostgreSQL"

info "Waiting for PostgreSQL StatefulSet to be ready (up to 5 minutes)..."
kubectl rollout status statefulset/awx-postgres \
  --namespace="$NAMESPACE" \
  --timeout=300s || warn "PostgreSQL rollout timeout — check: kubectl get pods -n $NAMESPACE"

# ── Wait for AWX ──────────────────────────────────────────────
section "Waiting for AWX"

info "AWX Operator is reconciling... this can take 5-15 minutes on first deploy."
info "Watch progress: kubectl get pods -n $NAMESPACE -w"
info ""

# Poll for AWX deployment to appear (operator creates it asynchronously)
TIMEOUT=900  # 15 minutes
ELAPSED=0
INTERVAL=15

until kubectl get deployment awx -n "$NAMESPACE" &>/dev/null; do
  if [[ $ELAPSED -ge $TIMEOUT ]]; then
    warn "AWX deployment not created after ${TIMEOUT}s."
    warn "Check operator logs: kubectl logs -n awx-operator-system deployment/awx-operator-controller-manager -c manager"
    break
  fi
  info "Waiting for AWX deployment to be created... ($ELAPSED/${TIMEOUT}s)"
  sleep $INTERVAL
  ELAPSED=$((ELAPSED + INTERVAL))
done

if kubectl get deployment awx -n "$NAMESPACE" &>/dev/null; then
  info "AWX deployment found. Waiting for it to be ready..."
  kubectl rollout status deployment/awx \
    --namespace="$NAMESPACE" \
    --timeout=600s || warn "AWX rollout timeout — check pod logs."
fi

# ── Print access info ─────────────────────────────────────────
section "Deployment Complete"

info "Environment:  $ENVIRONMENT"
info "Namespace:    $NAMESPACE"
info ""

# Get admin password
ADMIN_PASSWORD=$(kubectl get secret awx-admin-password -n "$NAMESPACE" \
  -o jsonpath='{.data.password}' 2>/dev/null | base64 -d 2>/dev/null || echo "<not yet available>")

info "AWX Admin Password: $ADMIN_PASSWORD"
info ""

# Get service URL
SVC_TYPE=$(kubectl get svc awx-service -n "$NAMESPACE" -o jsonpath='{.spec.type}' 2>/dev/null || echo "unknown")
if [[ "$SVC_TYPE" == "LoadBalancer" ]]; then
  EXTERNAL_IP=$(kubectl get svc awx-service -n "$NAMESPACE" \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
  info "AWX URL: http://$EXTERNAL_IP"
elif [[ "$SVC_TYPE" == "NodePort" ]]; then
  NODE_PORT=$(kubectl get svc awx-service -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
  NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}' 2>/dev/null)
  info "AWX URL: http://$NODE_IP:$NODE_PORT"
else
  info "Port-forward: kubectl port-forward svc/awx-service -n $NAMESPACE 8080:80"
  info "Then open:    http://localhost:8080"
fi

info ""
info "Run health check: ./scripts/healthcheck.sh $ENVIRONMENT"
