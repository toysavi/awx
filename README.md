# Infrastructure as Code — AWX on k3s

## Project Structure

```
.
├── ansible.cfg                              # roles_path + inventory config
├── ansible/
│   ├── inventory/
│   │   ├── hosts.yml                        # Host inventory
│   │   └── group_vars/all.yml               # Global variables (auto-loaded)
│   ├── group_vars/all.yml                   # Global variables
│   ├── awx-deployment/                      # AWX on k3s — self-contained project
│   │   ├── awx_site.yml                     # Main orchestration playbook
│   │   ├── awx_group_vars/all.yml           # AWX-specific overrides
│   │   ├── awx_inventory/hosts.yml          # Standalone inventory
│   │   └── awx_roles/
│   │       ├── common/                      # System prerequisites
│   │       ├── k3s/                         # k3s install & config
│   │       ├── kubectl/                     # kubectl setup
│   │       ├── awx_operator/               # AWX Operator (kustomize)
│   │       ├── awx/                         # AWX instance + CRD
│   │       ├── ingress/                     # Traefik ingress
│   │       └── cert_manager/               # Optional Let's Encrypt TLS
│   └── playbook/                            # General-purpose automation roles
│       ├── add_hosts/    ├── apache/    ├── aws/        ├── common-server/
│       ├── common/       ├── crowdstrike/ ├── deploy_vm/ ├── docker/
│       ├── git/          ├── java/      ├── jboss/      ├── nginx/
│       ├── os_hardening/ ├── patching/  ├── remove_host/ ├── server-info/
│       └── ssh_hardening/
└── terraform/                               # Cloud infra provisioning
```

---

## Quick Start

### Step 1 — Clone and configure

```bash
git clone <your-repo-url> /opt/iac
cd /opt/iac

pip3 install ansible --break-system-packages
```

### Step 2 — Edit inventory

```yaml
# ansible/inventory/hosts.yml
k3s_masters:
  hosts:
    awx-master-01:
      ansible_host: 127.0.0.1
      ansible_connection: local   # deploy on this server directly
      ip: 192.168.1.240           # this server's real IP
      k3s_role: server
```

### Step 3 — Edit variables

```bash
vi ansible/inventory/group_vars/all.yml
vi ansible/awx-deployment/awx_group_vars/all.yml
```

Minimum changes:
```yaml
awx_fqdn: awx.example.com
awx_admin_password: "YourSecurePassword"
timezone: Asia/Phnom_Penh
```

If behind a proxy, uncomment in `group_vars/all.yml`:
```yaml
https_proxy: "http://proxy.example.com:3128"
http_proxy: "http://proxy.example.com:3128"
```

### Step 4 — Deploy

```bash
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/awx-deployment/awx_site.yml -v
```

### Step 5 — Access AWX

```
http://awx.example.com   (or http://<server-ip>)
Username: admin
Password: value of awx_admin_password
```

---

## Version Matrix (tested & working)

| Component        | Version   | Notes                                      |
|------------------|-----------|--------------------------------------------|
| AWX Operator     | 2.19.1    | Installed via kustomize (not single YAML)  |
| AWX              | 24.6.1    | Must match operator's bundled image        |
| PostgreSQL       | 15        | Managed by operator                        |
| kube-rbac-proxy  | v0.15.0   | Remapped from gcr.io → quay.io/brancz     |
| k3s              | v1.30.0+k3s1 | Note: +k3s1 suffix required             |

---

## Run by Tags

```bash
ansible-playbook ... --tags common        # System packages, kernel config
ansible-playbook ... --tags k3s           # k3s install only
ansible-playbook ... --tags kubectl       # kubectl setup only
ansible-playbook ... --tags awx_operator  # AWX Operator only
ansible-playbook ... --tags awx           # AWX instance only
ansible-playbook ... --tags ingress       # Traefik ingress only
ansible-playbook ... --tags cert_manager  # TLS only
```

---

## Known Issues & Fixes Applied

### 1. roles not found
**Cause:** `ansible.cfg` `roles_path` must include both `ansible/playbook` AND `ansible/awx-deployment/awx_roles`
**Fix:** `roles_path = ansible/playbook:ansible/awx-deployment/awx_roles`

### 2. `k3s_role` / `k3s_cluster_cidr` undefined
**Cause:** Variables not defined in role defaults or group_vars not loaded
**Fix:** Added defaults to `k3s/defaults/main.yml`; `group_vars` must be at `ansible/inventory/group_vars/all.yml`

### 3. k3s download failed
**Cause:** Server behind proxy or firewall blocking GitHub
**Fix:** Set `https_proxy` / `http_proxy` in `group_vars/all.yml`; or set `k3s_skip_download: "true"` and pre-place binary

### 4. `web_manage_replicas` undefined in operator
**Cause:** `awx-operator:latest` is a broken nightly build
**Fix:** Pin operator to `2.19.1` using kustomize; never use `:latest`

### 5. AWX Operator deploy/awx-operator.yaml 404
**Cause:** AWX Operator 2.x removed single-file manifest; uses kustomize
**Fix:** `kustomize build github.com/ansible/awx-operator/config/default?ref=2.19.1`

### 6. `gcr.io/kubebuilder/kube-rbac-proxy` ImagePullBackOff
**Cause:** `gcr.io/kubebuilder` registry was shut down by Google
**Fix:** Remap in kustomization.yaml to `quay.io/brancz/kube-rbac-proxy:v0.15.0`

### 7. `image_version: 24.1.0` mismatch
**Cause:** AWX image version must match operator's bundled version
**Fix:** Operator 2.19.1 ships with AWX 24.6.1 — use `awx_version: "24.6.1"`

---

## Post-Deployment Verification

```bash
# Cluster nodes
k3s kubectl get nodes

# All pods
k3s kubectl get pods -A

# AWX pods specifically
k3s kubectl get pods -n awx

# AWX CR status
k3s kubectl get awx awx -n awx

# Storage
k3s kubectl get pvc -n awx

# Get admin password
k3s kubectl get secret awx-admin-password \
  -n awx -o jsonpath='{.data.password}' | base64 -d
```

---

## General Automation Roles

`ansible.cfg` sets `roles_path = ansible/playbook` so any playbook can use these roles by name:

```yaml
# example.yml
- hosts: all
  roles:
    - patching
    - os_hardening
    - ssh_hardening
    - docker
```

```bash
ansible-playbook -i ansible/inventory/hosts.yml example.yml -v
```

---

## Scaling

### Single-node → HA (3 masters)
```yaml
k3s_masters:
  hosts:
    awx-master-01: {ansible_host: 192.168.1.10, ip: 192.168.1.10}
    awx-master-02: {ansible_host: 192.168.1.11, ip: 192.168.1.11}
    awx-master-03: {ansible_host: 192.168.1.12, ip: 192.168.1.12}
```

### Add workers
```yaml
k3s_workers:
  hosts:
    awx-worker-01: {ansible_host: 192.168.1.20, ip: 192.168.1.20, k3s_role: agent}
```

Re-run the playbook — k3s role handles joining idempotently.
