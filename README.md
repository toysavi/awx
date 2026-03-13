# AWX on Rancher — Production Deployment

Deploy AWX (Ansible Tower) on Ubuntu 24.04 using **k3s + Rancher + Traefik + AWX Operator**.

## Architecture

```
Internet (port 80/443)
        │
        ▼
Azure VM — Ubuntu 24.04
        │
        ▼
k3s (Kubernetes v1.34+)
        ├── Traefik          (Ingress + TLS + Security)
        ├── cert-manager     (Certificate management)
        ├── Rancher          → https://YOUR_IP.nip.io
        └── AWX Operator
                ├── awx-web
                ├── awx-task
                ├── awx-postgres
                └── redis (sidecar)
```

## Prerequisites

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| OS | Ubuntu 24.04 LTS | Ubuntu 24.04 LTS |
| CPU | 4 vCPU | 8 vCPU |
| RAM | 8 GB | 16 GB |
| Disk | 50 GB | 100 GB |
| Ports open | 22, 80, 443, 6443 | 22, 80, 443, 6443 |

---

## Quick Start 

```bash
git clone https://github.com/toysavi/awx.git
cd awx-rancher
chmod +x scripts/*.sh
./scripts/install.sh
```

---

## Step-by-Step Installation

### 1 — Install k3s

```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --write-kubeconfig-mode=644" sh -
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> ~/.bashrc
kubectl get nodes
```

### 2 — Install Helm

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### 3 — Install cert-manager

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

### 4 — Install Rancher

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
echo "Rancher: https://${PUBLIC_IP}.nip.io/dashboard/?setup=admin"
```

### 5 — Configure Traefik

```bash
./scripts/setup-traefik.sh
```

### 6 — Install AWX Operator

```bash
helm repo add awx-operator https://ansible-community.github.io/awx-operator-helm/
helm repo update

helm install awx-operator awx-operator/awx-operator \
  --namespace awx \
  --create-namespace \
  -f k8s/operator/values.yaml

kubectl get pods -n awx -w
```

### 7 — Deploy AWX Instance

```bash
PUBLIC_IP=$(curl -s ifconfig.me)
sed "s/REPLACE_WITH_IP/${PUBLIC_IP}/g" k8s/awx/awx-instance.yaml | kubectl apply -f -
kubectl get pods -n awx -w
```

### 8 — Get AWX Admin Password

```bash
kubectl get secret awx-admin-password -n awx \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

---

## Access

| Service | URL | Credentials |
|---------|-----|-------------|
| Rancher | `https://YOUR_IP.nip.io` | admin / (set on first login) |
| AWX | `https://awx.YOUR_IP.nip.io` | admin / (see Step 8) |
| Traefik Dashboard | `https://traefik.YOUR_IP.nip.io/dashboard/` | admin / (set during setup-traefik.sh) |

---

## Repository Structure

```
awx-rancher/
├── README.md
├── .gitignore
├── .github/
│   └── workflows/
│       ├── deploy.yml           # CI/CD pipeline
│       └── validate.yml         # PR validation
├── k8s/
│   ├── operator/
│   │   └── values.yaml          # AWX Operator Helm values
│   └── awx/
│       ├── awx-instance.yaml    # AWX CR — dev/UAT
│       └── awx-instance-prod.yaml # AWX CR — production
├── traefik/
│   ├── README.md
│   ├── config/
│   │   ├── traefik-config.yaml  # Traefik HelmChartConfig
│   │   └── ingressroutes.yaml   # AWX + Rancher routes
│   ├── middleware/
│   │   └── middleware.yaml      # Security headers, rate limit, auth
│   ├── dashboard/
│   │   └── dashboard-ingress.yaml
│   └── tls/
│       └── letsencrypt.yaml     # Let's Encrypt (real domain)
├── awx-config/
│   ├── README.md
│   ├── organizations/           # Orgs, Teams, Users, RBAC
│   ├── credentials/             # SSH, Git, Vault, Azure
│   ├── inventories/             # Hosts and groups
│   ├── projects/                # Git-linked projects
│   ├── templates/               # Job templates
│   ├── workflows/               # Workflow templates
│   ├── notifications/           # Telegram, Email, Slack
│   ├── schedules/               # Scheduled jobs
│   └── scripts/
│       ├── configure-all.yml    # Apply all AWX config
│       ├── export.sh            # Export AWX config to YAML
│       └── import.sh            # Import AWX config from YAML
├── scripts/
│   ├── install.sh               # Full install (k3s+Rancher+AWX)
│   ├── setup-traefik.sh         # Configure Traefik
│   ├── healthcheck.sh           # Check all services
│   ├── backup.sh                # Backup DB + secrets
│   └── uninstall.sh             # Clean uninstall
├── ansible/
│   ├── inventories/
│   │   ├── dev/hosts.yml
│   │   └── prod/hosts.yml
│   └── playbooks/
│       └── site.yml             # Full server setup playbook
└── docs/
    ├── troubleshooting.md
    └── github-secrets.md
```

---

## Upgrading AWX

```bash
kubectl edit awx awx -n awx
# Change spec.image_version to new version
# Operator handles rolling upgrade automatically
```

## Backup & Restore

```bash
# Backup
./scripts/backup.sh

# Restore DB
kubectl exec -n awx deployment/awx-web -- \
  awx-manage dbshell < /var/backups/awx/TIMESTAMP/awx_db.sql
```

---

## License

MIT
