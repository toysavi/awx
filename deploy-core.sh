#!/bin/bash
set -e
source config.env
export KUBECONFIG=$HOME/.kube/config

# Namespaces
kubectl get ns cattle-system >/dev/null 2>&1 || kubectl create ns cattle-system
kubectl get ns argocd >/dev/null 2>&1 || kubectl create ns argocd

# TLS Secrets
kubectl get secret rancher-tls -n cattle-system >/dev/null 2>&1 || \
kubectl create secret tls rancher-tls --cert=${SSL_CERT_PATH} --key=${SSL_KEY_PATH} -n cattle-system

kubectl get secret argocd-tls -n argocd >/dev/null 2>&1 || \
kubectl create secret tls argocd-tls --cert=${SSL_CERT_PATH} --key=${SSL_KEY_PATH} -n argocd

# Helm repos
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest || true
helm repo update

# Rancher install / upgrade
if helm status rancher -n cattle-system >/dev/null 2>&1; then
    echo "Upgrading existing Rancher release..."
    helm upgrade rancher rancher-latest/rancher \
      -n cattle-system \
      --set hostname=${RANCHER_HOST} \
      --set bootstrapPassword=${RANCHER_BOOTSTRAP_PASSWORD} \
      --set ingress.tls.source=secret
else
    echo "Installing Rancher..."
    helm install rancher rancher-latest/rancher \
      -n cattle-system \
      --set hostname=${RANCHER_HOST} \
      --set bootstrapPassword=${RANCHER_BOOTSTRAP_PASSWORD} \
      --set ingress.tls.source=secret
fi

# Argo CD
kubectl get deployment argocd-server -n argocd >/dev/null 2>&1 || \
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Argo CD Ingress
envsubst < templates/ingress.yaml.tpl | kubectl apply -f -