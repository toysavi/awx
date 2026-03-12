# AWX GitOps Deployment

Production-ready AWX (Ansible Tower open-source) deployment using Kubernetes with the AWX Operator, PostgreSQL, and full GitOps practices.

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│                  Kubernetes Cluster                  │
│                                                     │
│  ┌──────────────┐      ┌──────────────────────────┐ │
│  │ AWX Operator │─────▶│    AWX Deployment        │ │
│  └──────────────┘      │  ┌────────┐ ┌─────────┐  │ │
│                        │  │  web   │ │  task   │  │ │
│                        │  └────────┘ └─────────┘  │ │
│                        └────────────┬─────────────┘ │
│                                     │               │
│                        ┌────────────▼─────────────┐ │
│                        │   PostgreSQL StatefulSet  │ │
│                        └──────────────────────────┘ │
│                                                     │
│  ┌──────────────────────────────────────────────┐   │
│  │           Ingress / LoadBalancer             │   │
│  └──────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

## Prerequisites

- Ubuntu 22.04+ server (minimum 4 CPU, 8GB RAM, 40GB disk)
- `kubectl` v1.28+
- `kustomize` v5+
- `helm` v3.12+
- `k3s` or an existing Kubernetes cluster
- `git`

## Quick Start

### 1. Clone this repository
```bash
git clone https://github.com/YOUR_ORG/awx-gitops.git
cd awx-gitops
```

### 2. Bootstrap the cluster (fresh Ubuntu server)
```bash
chmod +x scripts/bootstrap.sh
sudo ./scripts/bootstrap.sh
```

### 3. Configure secrets
```bash
# Copy the example secrets file and edit with your values
cp k8s/base/secrets.env.example k8s/base/secrets.env
vim k8s/base/secrets.env

# Generate Kubernetes secrets from env file
./scripts/generate-secrets.sh dev
```

### 4. Deploy to an environment
```bash
# Deploy to dev
./scripts/deploy.sh dev

# Deploy to staging
./scripts/deploy.sh staging

# Deploy to prod
./scripts/deploy.sh prod
```

### 5. Access AWX Web UI
```bash
# Get the AWX admin password
kubectl get secret awx-admin-password -n awx-dev -o jsonpath='{.data.password}' | base64 -d

# Port-forward for local access
kubectl port-forward svc/awx-service -n awx-dev 8080:80

# Or get the LoadBalancer/NodePort URL
kubectl get svc awx-service -n awx-dev
```

Open browser: `http://localhost:8080` (admin / <password from above>)

## Repository Structure

```
awx-gitops/
├── README.md                          # This file
├── k8s/
│   ├── operator/                      # AWX Operator installation
│   │   └── kustomization.yaml
│   ├── base/                          # Base Kubernetes manifests (shared)
│   │   ├── kustomization.yaml
│   │   ├── namespace.yaml
│   │   ├── postgres/
│   │   │   ├── statefulset.yaml       # PostgreSQL StatefulSet
│   │   │   ├── service.yaml           # PostgreSQL Service
│   │   │   ├── pvc.yaml               # Persistent Volume Claim
│   │   │   └── configmap.yaml         # PostgreSQL init config
│   │   ├── awx/
│   │   │   ├── awx-instance.yaml      # AWX CR (Custom Resource)
│   │   │   └── ingress.yaml           # Ingress for web UI
│   │   └── secrets.env.example        # Example secrets (never commit real values)
│   └── overlays/
│       ├── dev/                       # Dev environment overrides
│       │   ├── kustomization.yaml
│       │   └── patch-resources.yaml
│       ├── staging/                   # Staging overrides
│       │   ├── kustomization.yaml
│       │   └── patch-resources.yaml
│       └── prod/                      # Production overrides
│           ├── kustomization.yaml
│           └── patch-resources.yaml
├── awx/
│   ├── awx-config.yaml                # AWX application config
│   └── inventory                      # AWX inventory reference
├── postgres/
│   └── init.sql                       # Database initialization SQL
├── ansible/
│   ├── inventories/
│   │   ├── dev/hosts.yml
│   │   ├── staging/hosts.yml
│   │   └── prod/hosts.yml
│   └── playbooks/
│       ├── site.yml                   # Master playbook
│       ├── deploy-awx.yml             # AWX deployment playbook
│       └── configure-awx.yml          # AWX post-deploy config
├── scripts/
│   ├── bootstrap.sh                   # Server bootstrap (k3s + tools)
│   ├── deploy.sh                      # Main deploy entrypoint
│   ├── generate-secrets.sh            # Secret generation helper
│   └── healthcheck.sh                 # Post-deploy health check
├── docs/
│   ├── architecture.md
│   ├── secrets-management.md
│   └── troubleshooting.md
└── .github/
    └── workflows/
        ├── deploy.yml                 # Main GitOps CD pipeline
        ├── validate.yml               # PR validation (lint + dry-run)
        └── security-scan.yml          # Secret scanning + CVE checks
```

## Environment Configuration

| Environment | Namespace  | Replicas | Resources       | Ingress               |
|-------------|------------|----------|-----------------|-----------------------|
| dev         | awx-dev    | 1        | 1CPU / 2Gi      | awx-dev.example.com   |
| staging     | awx-staging| 1        | 2CPU / 4Gi      | awx-staging.example.com|
| prod        | awx-prod   | 2        | 4CPU / 8Gi      | awx.example.com       |

## Secrets Management

Secrets are **never committed to Git**. See [docs/secrets-management.md](docs/secrets-management.md) for details.

Summary of approach:
- Kubernetes Secrets created from local `.env` files (gitignored)
- In CI/CD: secrets injected from GitHub Actions Secrets → Kubernetes Secrets
- PostgreSQL passwords auto-generated on first deploy if not provided
- Optional: integrate with HashiCorp Vault or AWS Secrets Manager

## CI/CD Pipeline

GitHub Actions workflows:
- **PR**: Runs `kustomize build` dry-run + kubeconform validation + trivy scan
- **Push to `main`**: Auto-deploys to `dev`
- **Push to `release/*`**: Deploys to `staging`
- **Manual trigger**: Deploy to `prod` (requires approval)

## Local Development

```bash
# Validate manifests without deploying
./scripts/deploy.sh dev --dry-run

# Watch AWX pods come up
kubectl get pods -n awx-dev -w

# View AWX operator logs
kubectl logs -n awx-operator-system deployment/awx-operator-controller-manager -c manager -f

# View AWX task logs
kubectl logs -n awx-dev deployment/awx -c awx-task -f
```

## Updating AWX Version

Edit the version in `k8s/operator/kustomization.yaml`:
```yaml
images:
  - name: quay.io/ansible/awx-operator
    newTag: "2.19.1"  # Change this
```

Then run: `./scripts/deploy.sh <env>`
