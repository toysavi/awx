#!/usr/bin/env bash
# scripts/generate-secrets.sh
# ============================================================
# Creates Kubernetes Secrets from a local secrets.env file.
# Used for local deployments and CI/CD pipelines.
#
# Usage:
#   ./scripts/generate-secrets.sh <environment>
#   ./scripts/generate-secrets.sh dev
#
# In CI/CD (GitHub Actions), this is called after writing
# the secrets.env file from GitHub Actions Secrets.
# ============================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

ENVIRONMENT="${1:-}"
[[ -z "$ENVIRONMENT" ]] && error "Usage: $0 <dev|staging|prod>"

NAMESPACE="awx-${ENVIRONMENT}"
SECRETS_FILE="k8s/overlays/${ENVIRONMENT}/secrets.env"

# Load secrets from env file
[[ -f "$SECRETS_FILE" ]] || error "Secrets file not found: $SECRETS_FILE"

# shellcheck source=/dev/null
source "$SECRETS_FILE"

# Validate required variables
: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD not set in $SECRETS_FILE}"
: "${POSTGRES_DB:?POSTGRES_DB not set in $SECRETS_FILE}"
: "${POSTGRES_USER:?POSTGRES_USER not set in $SECRETS_FILE}"
: "${AWX_ADMIN_PASSWORD:?AWX_ADMIN_PASSWORD not set in $SECRETS_FILE}"

# Ensure namespace exists
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# ── PostgreSQL credentials secret ─────────────────────────────
info "Creating awx-postgres-secret in namespace $NAMESPACE..."
kubectl create secret generic awx-postgres-secret \
  --namespace="$NAMESPACE" \
  --from-literal=POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
  --from-literal=POSTGRES_DB="$POSTGRES_DB" \
  --from-literal=POSTGRES_USER="$POSTGRES_USER" \
  --dry-run=client -o yaml | kubectl apply -f -

# ── AWX postgres configuration secret (used by AWX CR) ────────
info "Creating awx-postgres-configuration in namespace $NAMESPACE..."
kubectl create secret generic awx-postgres-configuration \
  --namespace="$NAMESPACE" \
  --from-literal=host="awx-postgres.${NAMESPACE}.svc.cluster.local" \
  --from-literal=port="5432" \
  --from-literal=database="$POSTGRES_DB" \
  --from-literal=username="$POSTGRES_USER" \
  --from-literal=password="$POSTGRES_PASSWORD" \
  --from-literal=sslmode="prefer" \
  --dry-run=client -o yaml | kubectl apply -f -

# ── AWX admin password secret ─────────────────────────────────
info "Creating awx-admin-password in namespace $NAMESPACE..."
kubectl create secret generic awx-admin-password \
  --namespace="$NAMESPACE" \
  --from-literal=password="$AWX_ADMIN_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

info "All secrets created in namespace: $NAMESPACE"
info "Verify: kubectl get secrets -n $NAMESPACE"
