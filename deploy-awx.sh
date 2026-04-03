#!/bin/bash
set -e
source config.env

kubectl create ns awx || true

kubectl create secret tls awx-tls \
  --cert=${SSL_CERT_PATH} \
  --key=${SSL_KEY_PATH} \
  -n awx || true

echo "=== Deploy AWX via ArgoCD ==="
kubectl apply -f argocd-app.yaml