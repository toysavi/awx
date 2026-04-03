#!/bin/bash
set -e
source config.env

kubectl create ns gitlab || true

kubectl create secret tls gitlab-tls \
  --cert=${SSL_CERT_PATH} \
  --key=${SSL_KEY_PATH} \
  -n gitlab || true

helm repo add gitlab https://charts.gitlab.io/
helm repo update

echo "=== Deploy GitLab ==="
envsubst < templates/gitlab-values.yaml.tpl > gitlab-values.yaml

helm install gitlab gitlab/gitlab \
  -n gitlab \
  -f gitlab-values.yaml