#!/bin/bash
set -e
source config.env
export KUBECONFIG=$HOME/.kube/config

kubectl get ns awx >/dev/null 2>&1 || kubectl create ns awx

kubectl get secret awx-tls -n awx >/dev/null 2>&1 || \
kubectl create secret tls awx-tls --cert=${SSL_CERT_PATH} --key=${SSL_KEY_PATH} -n awx

# Deploy AWX via Argo CD
envsubst < templates/awx-app.yaml.tpl | kubectl apply -f -