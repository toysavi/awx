# AWX on Rancher (k3s) — Production Deployment

Deploy AWX (Ansible Tower) on Ubuntu 24 using k3s + Rancher + AWX Operator.

## Architecture

```
Internet
    │
    ▼
Azure VM (Ubuntu 24)
    │
    ├── k3s (Kubernetes v1.34+)
    │       ├── Traefik (Ingress, ports 80/443)
    │       ├── cert-manager (TLS certificates)
    │       ├── Rancher (Cluster UI)  → https://<IP>.nip.io
    │       └── AWX Operator
    │               ├── awx-web
    │               ├── awx-task
    │               ├── awx-postgres
    │               └── redis (sidecar)
    │
    └── Docker Compose (optional fallback)
            ├── awx-web
            ├── awx-task
            ├── postgres
            └── redis
```

## Prerequisites

- Ubuntu 24.04 LTS
- 4 vCPU / 8GB RAM minimum
- Ports open: 22, 80, 443, 6443
- Domain or nip.io (e.g. `20.84.49.131.nip.io`)

---

## Quick Start

### 1. Clone the repo

```bash
git clone https://github.com/yourorg/awx-rancher.git
cd awx-rancher
chmod +x scripts/*.sh
```

### 2. Install k3s + Rancher + AWX

```bash
./scripts/install.sh
```

### 3. Access

| Service | URL |
|---------|-----|
| Rancher | `https://<IP>.nip.io` |
| AWX     | `https://awx.<IP>.nip.io` |

---

## Manual Step-by-Step

### Step 1 — Install k3s

```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --write-kubeconfig-mode=644" sh -
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> ~/.bashrc
kubectl get nodes
```

### Step 2 — Install Helm

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### Step 3 — Install cert-manager

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.crds.yaml

helm repo add jetstack https://charts.jetstack.io
helm repo update

helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.14.4

kubectl wait --for=condition=Ready pods --all -n cert-manager --timeout=120s
```

### Step 4 — Install Rancher

```bash
PUBLIC_IP=$(curl -s ifconfig.me)

helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
helm repo update

helm install rancher rancher-stable/rancher \
  --namespace cattle-system \
  --create-namespace \
  --set hostname=${PUBLIC_IP}.nip.io \
  --set bootstrapPassword=admin \
  --set ingress.tls.source=rancher \
  --set replicas=1

kubectl rollout status deployment/rancher -n cattle-system --timeout=300s

echo "Rancher URL: https://${PUBLIC_IP}.nip.io/dashboard/?setup=admin"
```

### Step 5 — Install AWX Operator

```bash
helm repo add awx-operator https://ansible-community.github.io/awx-operator-helm/
helm repo update

helm install awx-operator awx-operator/awx-operator \
  --namespace awx \
  --create-namespace

kubectl get pods -n awx -w
```

### Step 6 — Deploy AWX Instance

```bash
PUBLIC_IP=$(curl -s ifconfig.me)

kubectl apply -f - <<EOF
apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: awx
  namespace: awx
spec:
  service_type: ClusterIP
  ingress_type: ingress
  ingress_class_name: traefik
  hostname: awx.${PUBLIC_IP}.nip.io
  admin_user: admin
  admin_email: admin@example.com
  postgres_storage_class: local-path
  projects_storage_class: local-path
  projects_storage_size: 8Gi
  web_resource_requirements:
    requests:
      memory: 512Mi
      cpu: 500m
  task_resource_requirements:
    requests:
      memory: 512Mi
      cpu: 500m
EOF

kubectl get pods -n awx -w
```

### Step 7 — Get AWX Admin Password

```bash
kubectl get secret awx-admin-password -n awx \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

---

## Configuration Files

| File | Description |
|------|-------------|
| `k8s/awx/awx-instance.yaml` | AWX Custom Resource |
| `k8s/awx/awx-instance-prod.yaml` | AWX CR with resource limits for production |
| `scripts/install.sh` | Full automated install script |
| `scripts/uninstall.sh` | Clean uninstall |
| `scripts/healthcheck.sh` | Check all services |
| `scripts/backup.sh` | Backup AWX database |
| `ansible/playbooks/site.yml` | Ansible playbook for server setup |

---

## Upgrading AWX

```bash
# Edit the AWX instance version
kubectl edit awx awx -n awx
# Change: spec.image_version: 24.6.1 → new version
# Operator will handle rolling upgrade automatically
```

---

## Troubleshooting

See [docs/troubleshooting.md](docs/troubleshooting.md)

---

## License

MIT
