#!/bin/bash
set -e
source config.env

echo "=== Install K3s ==="
curl -sfL https://get.k3s.io | sh -

mkdir -p $HOME/.kube
sudo cp ${KUBECONFIG_PATH} $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

export KUBECONFIG=$HOME/.kube/config

echo "=== Install Helm ==="
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo "=== Done ==="