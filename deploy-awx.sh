#!/bin/bash
set -e
source config.env
export KUBECONFIG=$HOME/.kube/config

kubectl create ns awx || true

kubectl create secret tls awx-tls --cert=${SSL_CERT_PATH} --key=${SSL_KEY_PATH} -n awx || true

# Apply AWX Argo CD app
envsubst < templates/awx-app.yaml.tpl | kubectl apply -f -