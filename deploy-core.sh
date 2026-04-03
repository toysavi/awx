#!/bin/bash
set -e
source config.env

export KUBECONFIG=$HOME/.kube/config

kubectl create ns cattle-system || true
kubectl create ns argocd || true

echo "=== TLS Secrets ==="
kubectl create secret tls rancher-tls \
  --cert=${SSL_CERT_PATH} \
  --key=${SSL_KEY_PATH} \
  -n cattle-system || true

kubectl create secret tls argocd-tls \
  --cert=${SSL_CERT_PATH} \
  --key=${SSL_KEY_PATH} \
  -n argocd || true

echo "=== Rancher ==="
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm repo update

helm install rancher rancher-latest/rancher \
  -n cattle-system \
  --set hostname=${RANCHER_HOST} \
  --set bootstrapPassword=${RANCHER_BOOTSTRAP_PASSWORD} \
  --set ingress.tls.source=secret

echo "=== Argo CD ==="
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "=== ArgoCD Ingress ==="
envsubst < templates/ingress.yaml.tpl | kubectl apply -f -