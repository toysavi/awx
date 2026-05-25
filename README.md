# AWX on k3s with Oracle Linux (Ansible IaC)

This repository contains a production-ready Infrastructure-as-Code solution to deploy **AWX** on a **k3s Kubernetes cluster** running on **Oracle Linux** using **Ansible**.

---

## 📋 Prerequisites

- Oracle Linux 8/9 (minimal install recommended)
- SSH access to target node(s)
- Ansible installed on your control machine
- Internet connectivity
- DNS entry pointing your chosen FQDN (e.g., `awx.example.com`) to the node IP

---

## 📂 Project Structure

```ansible-awx-k3s/
├── inventory/
│   └── hosts.yml
├── group_vars/
│   └── all.yml
├── roles/
│   ├── common/
│   ├── k3s/
│   ├── kubectl/
│   ├── awx_operator/
│   ├── awx/
│   └── ingress/
├── templates/
│   ├── awx.yml.j2
│   └── ingress.yml.j2
├── playbooks/
│   └── site.yml
```

---

## ⚙️ Configuration

Edit `group_vars/all.yml` to set your environment:


```fqdn: "awx.example.com"
timezone: "Asia/Phnom_Penh"
k3s_version: "v1.29.3+k3s1"
storage_class: "local-path"
postgres_storage_size: "20Gi"
awx_admin_user: "admin"
awx_admin_password: "SuperSecretPassword123"
```

🔐 Use ansible-vault to encrypt sensitive values like awx_admin_password.


## 📑 Inventory
Define your Oracle Linux host(s) in `inventory/hosts.yml`:

```all:
  hosts:
    awx-node:
      ansible_host: 192.168.1.100
      ansible_user: oracle
      ansible_become: true
```

## 🚀 Installation Steps

1. Clone the repository
```
git clone https://your-repo/ansible-awx-k3s.git
cd ansible-awx-k3s
```
2. Run the playbook
```
ansible-playbook -i inventory/hosts.yml playbooks/site.yml
```
3. Verify k3s cluster
```
kubectl get nodes
```
4. Check AWX deployment
```
kubectl get pods -n awx
```

5. Access AWX
- Navigate to `http://awx.example.com`
- Login with the admin credentials defined in `group_vars/all.yml`


## 🌐 Optional TLS Setup
For HTTPS, install cert-manager and configure Let’s Encrypt:

Update ``templates/ingress.yml.j2`` with TLS annotations and certificate references.
- Modify to: 
```apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: awx-ingress
  annotations:
    kubernetes.io/ingress.class: traefik
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
    - hosts:
        - {{ fqdn }}
      secretName: awx-tls-secret
  rules:
    - host: {{ fqdn }}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: awx-service
                port:
                  number: 80
```
1. Install cert-manager:
```
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.yaml
```
2. Create ClusterIssuer for Let’s Encrypt (example for production):

```apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-prod-key
    solvers:
      - http01:
          ingress:
            class: traefik
```
Apply it:
```
kubectl apply -f clusterissuer.yaml
```
3. Deploy ingress with TLS:
- Your updated `ingress.yml.j2` will generate the manifest with TLS enabled.
- Run:
```
ansible-playbook -i inventory/hosts.yml playbooks/site.yml
```
4. Verify certificate:
```
kubectl describe certificate awx-tls-secret
```

