# 🚀 DevOps Platform Deployment (K3s + Rancher + Argo CD + AWX + GitLab EE)

## 📌 Overview
This repository provides a **complete DevOps platform deployment** from scratch with:

- K3s – lightweight Kubernetes distribution
- Traefik – Kubernetes ingress controller
- Rancher – Kubernetes management platform
- Argo CD – GitOps continuous delivery tool
- AWX – Ansible web UI project
- GitLab Enterprise Edition – DevOps platform
- LDAP integration for centralized authentication
- All services exposed via HTTPS (port 443) using FQDN

---

## 🏗 Stage 1: Prerequisites

### 1️⃣ Hardware Requirements

| Service / Setup | CPU | RAM | Storage |
|----------------|-----|-----|--------|
| Production: Rancher + Argo CD | 2 | 4 GB | 50 GB |
| Production: AWX | 4 | 8 GB | 50 GB |
| Production: GitLab EE | 4 | 8–16 GB | 100+ GB |
| UAT / All-in-One | 8 | 16 GB | 150+ GB |

---

### 2️⃣ DNS Configuration

Create A records pointing to your server IP:

```text
rancher.domain.com → SERVER_IP
argocd.domain.com → SERVER_IP
awx.domain.com → SERVER_IP
gitlab.domain.com → SERVER_IP
```
### 3️⃣ Firewall
```text
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

### 4️⃣ SSL Certificates

Provide your own SSL certificate:
- `tls.crt`
- `tls.key`

Recommended: wildcard certificate `*.domain.com`.

## 🏗 Stage 2: Preparation

### 1️⃣ Clone Repository
```
mkdir -p /opt/ssl
git clone https://github.com/toysavi/awx.git /devops-platform
cd /devops-platform
```
### 2️⃣ Configure Variables
Edit `config.env`:
```
# ===== DOMAIN =====
DOMAIN=example.com

RANCHER_HOST=rancher.${DOMAIN}
ARGOCD_HOST=argocd.${DOMAIN}
AWX_HOST=awx.${DOMAIN}
GITLAB_HOST=gitlab.${DOMAIN}

# ===== SSL =====
SSL_CERT_PATH=/opt/ssl/tls.crt
SSL_KEY_PATH=/opt/ssl/tls.key

# ===== LDAP =====
LDAP_HOST=ldap.example.com
LDAP_PORT=389
LDAP_BIND_DN="cn=admin,dc=example,dc=com"
LDAP_BIND_PASSWORD=adminpassword
LDAP_BASE_DN="dc=example,dc=com"

# ===== RANCHER =====
RANCHER_BOOTSTRAP_PASSWORD=Admin123!

# ===== GITLAB =====
GITLAB_ROOT_PASSWORD=GitlabAdmin123!

# ===== KUBERNETES =====
KUBECONFIG_PATH=/etc/rancher/k3s/k3s.yaml

# ===== Persistent Volumes =====
# GitLab
PV_GITLAB_POSTGRES=/mnt/pv/gitlab/postgres
PV_GITLAB_GITALY=/mnt/pv/gitlab/gitaly
PV_GITLAB_LOGS=/mnt/pv/gitlab/logs

# AWX
PV_AWX_POSTGRES=/mnt/pv/awx/postgres
PV_AWX_PROJECTS=/mnt/pv/awx/projects

# Argo CD
PV_ARGOCD_REPOS=/mnt/pv/argocd/repos
```
### 3️⃣ Install Dependencies & K3s

```
chmod +x install.sh
./install.sh
```
- Installs K3s, `kubectl`, `Helm`
- Copies kubeconfig to `$HOME/.kube/config`

### 4️⃣ Create Persistent Volume Directories

```
chmod +x create-pv-dirs.sh
./create-pv-dirs.sh
```
- Creates all directories defined in `config.env`
- Sets permissions to `755` and owned by current user

## 🏗 Stage 3: Deployment

### 1️⃣ Deploy Core Services (Rancher + Argo CD)

```
chmod +x deploy-core.sh
./deploy-core.sh
```
- Creates namespaces `cattle-system` and `argocd`
- Deploys Rancher and Argo CD
- Applies TLS secrets from your SSL certificate
- Configures ingress routing for FQDNs

### 2️⃣ Deploy GitLab EE

```
chmod +x deploy-gitlab.sh
./deploy-gitlab.sh
```
- Deploys GitLab Enterprise Edition via Helm
- Uses persistent volumes from `config.env`
- Configures root password via `config.env`
- TLS configured using provided certificate

### 3️⃣ Deploy AWX via Argo CD

```
chmod +x deploy-awx.sh
./deploy-awx.sh
```
- AWX deployed as an `Argo CD application`
- Uses persistent volumes for PostgreSQL and project data
- Configured TLS via provided certificate

## 🧩 Stage 4: Verification
Check pods:

```
kubectl get pods -A
```
Check persistent volumes:
```
kubectl get pvc -A
```
Check ingress:
```
kubectl get ingress -A
```
### 🔑 Access Credentials

| Service | User  | Password                   |
| ------- | ----- | -------------------------- |
| Rancher | admin | RANCHER_BOOTSTRAP_PASSWORD |
| Argo CD | admin | admin (change after login) |
| GitLab  | root  | GITLAB_ROOT_PASSWORD       |
| AWX     | admin | defined in AWX Helm values |

### ⚠️ Notes

- All services are exposed via HTTPS (443) using Traefik
- Persistent volumes created automatically from config.env
- LDAP integration can be added in Helm values and AWX/Rancher/Argo CD configs
- Recommended for production: use NFS or cloud storage for PVs
- Run `kubectl rollout restart deployment <name> -n <namespace>` to restart services if needed



---

**Author:** DevOps Platform 
**Version:** 1.0  
**Date:** 2026-04-03  
**Copyright:** © 2026 DevOps Platform Bootstrap. All rights reserved.