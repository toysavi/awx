#!/bin/bash
set -e
source config.env
export KUBECONFIG=$HOME/.kube/config

kubectl get ns gitlab >/dev/null 2>&1 || kubectl create ns gitlab

kubectl get secret gitlab-tls -n gitlab >/dev/null 2>&1 || \
kubectl create secret tls gitlab-tls --cert=${SSL_CERT_PATH} --key=${SSL_KEY_PATH} -n gitlab

helm repo add gitlab https://charts.gitlab.io/ || true
helm repo update

envsubst < templates/gitlab-values.yaml.tpl > gitlab-values.yaml

if helm status gitlab -n gitlab >/dev/null 2>&1; then
    echo "Upgrading existing GitLab release..."
    helm upgrade gitlab gitlab/gitlab -n gitlab -f gitlab-values.yaml
else
    echo "Installing GitLab release..."
    helm install gitlab gitlab/gitlab -n gitlab -f gitlab-values.yaml
fi