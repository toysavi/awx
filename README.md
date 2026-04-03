# 🚀 DevOps Platform Deployment (K3s + Rancher + Argo CD + AWX + GitLab EE)

## 📌 Overview

This project provides a **complete DevOps platform** built on:

* K3s
* Traefik (default ingress, HTTPS 443)
* Rancher
* Argo CD
* AWX
* GitLab Enterprise Edition
* LDAP integration (centralized authentication)

---

# 🧱 Architecture

## 🏭 Production

| Server   | Purpose           |
| -------- | ----------------- |
| Server 1 | Rancher + Argo CD |
| Server 2 | AWX               |
| Server 3 | GitLab EE         |

## 🧪 UAT

* Single server running all components

---

# 🌐 Network & Access

All services are exposed via **HTTPS (443)** using Traefik:

| Service | URL                        |
| ------- | -------------------------- |
| Rancher | https://rancher.domain.com |
| Argo CD | https://argocd.domain.com  |
| AWX     | https://awx.domain.com     |
| GitLab  | https://gitlab.domain.com  |

---

# ⚙️ Requirements

## 🖥️ Minimum Hardware

### Production

| Component         | CPU | RAM     | Storage |
| ----------------- | --- | ------- | ------- |
| Rancher + Argo CD | 2   | 4 GB    | 50 GB   |
| AWX               | 4   | 8 GB    | 50 GB   |
| GitLab EE         | 4   | 8–16 GB | 100+ GB |

### UAT (All-in-one)

* CPU: 8 cores
* RAM: 16 GB minimum
* Storage: 150+ GB

---

## 🌍 DNS Requirements

Configure A records:

```
rancher.domain.com → SERVER_IP
argocd.domain.com → SERVER_IP
awx.domain.com → SERVER_IP
gitlab.domain.com → SERVER_IP
```

---

## 🔐 SSL Requirements

Provide:

* `tls.crt`
* `tls.key`

Wildcard cert recommended:

```
*.domain.com
```

---

## 🔓 Firewall

Open ports:

```bash
80/tcp
443/tcp
```

---

# 📁 Project Structure

```
platform/
├── config.env
├── install.sh
├── deploy-core.sh
├── deploy-gitlab.sh
├── deploy-awx.sh
├── ldap/
│   └── ldap-config.sh
├── templates/
│   ├── ingress.yaml.tpl
│   ├── gitlab-values.yaml.tpl
│   └── awx.yaml.tpl
```

---

# ⚙️ Configuration

Edit:

```
config.env
```

Example:

```bash
DOMAIN=example.com

RANCHER_HOST=rancher.${DOMAIN}
ARGOCD_HOST=argocd.${DOMAIN}
AWX_HOST=awx.${DOMAIN}
GITLAB_HOST=gitlab.${DOMAIN}

SSL_CERT_PATH=/opt/ssl/tls.crt
SSL_KEY_PATH=/opt/ssl/tls.key
```

---

# 🚀 Deployment Guide

## 🧩 Step 1: Install Base System

```bash
chmod +x install.sh
./install.sh
```

This will install:

* K3s
* kubectl
* Helm

---

## 🧠 Step 2: Deploy Core Services

```bash
chmod +x deploy-core.sh
./deploy-core.sh
```

Deploys:

* Rancher
* Argo CD
* TLS configuration
* Ingress (Traefik)

---

## 🦊 Step 3: Deploy GitLab EE

```bash
chmod +x deploy-gitlab.sh
./deploy-gitlab.sh
```

⚠️ This step may take **10–20 minutes**

---

## 🤖 Step 4: Deploy AWX

```bash
chmod +x deploy-awx.sh
./deploy-awx.sh
```

AWX will be deployed via Argo CD (GitOps).

---

## 🔐 Step 5: Configure LDAP

```bash
cd ldap
chmod +x ldap-config.sh
./ldap-config.sh
```

LDAP will be applied to:

* Rancher
* Argo CD
* AWX
* GitLab

---

# 🔍 Verification

Check pods:

```bash
kubectl get pods -A
```

Check ingress:

```bash
kubectl get ingress -A
```

---

# 🔑 Access

| Service | Default User |
| ------- | ------------ |
| Rancher | admin        |
| Argo CD | admin        |
| GitLab  | root         |
| AWX     | admin        |

Passwords are defined in:

```
config.env
```

---

# ⚠️ Notes

* All services use **port 443 externally**
* Traefik handles routing via hostname
* Internal service ports remain unchanged
* GitLab requires high resources

---

# 🔧 Troubleshooting

## Check Traefik

```bash
kubectl get pods -n kube-system | grep traefik
```

## Check Logs

```bash
kubectl logs -n cattle-system deploy/rancher
kubectl logs -n argocd deploy/argocd-server
```

## Restart Deployment

```bash
kubectl rollout restart deployment <name> -n <namespace>
```

---

# 🧠 Best Practices

* Use wildcard SSL certificate
* Use external database for production
* Enable backups (Velero recommended)
* Avoid running everything on one node in production

---

# 🎯 Result

You will have a fully integrated platform:

* 🔐 LDAP Authentication
* 🔄 GitOps Deployment (Argo CD)
* 🐄 Cluster Management (Rancher)
* 🤖 Automation (AWX)
* 🦊 CI/CD (GitLab EE)
* 🌐 HTTPS via Traefik (443)

---

# 📌 Next Improvements

* HA cluster setup
* External PostgreSQL for AWX & GitLab
* Monitoring (Prometheus + Grafana)
* Secrets management (Vault)

---

**Author:** DevOps Platform Bootstrap
**Version:** 1.0
