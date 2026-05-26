# Infrastructure as Code — AWX on k3s

## Structure

```
.
├── ansible.cfg                          # Ansible config (roles_path, inventory)
├── ansible/
│   ├── inventory/hosts.yml              # Global host inventory
│   ├── group_vars/all.yml               # Global variables
│   ├── awx-deployment/                  # AWX on k3s deployment project
│   │   ├── awx_site.yml                 # Main AWX orchestration playbook
│   │   ├── awx_group_vars/all.yml       # AWX-specific variable overrides
│   │   ├── awx_inventory/hosts.yml      # AWX-specific inventory (standalone use)
│   │   └── awx_roles/                   # AWX deployment roles
│   │       ├── common/                  # System prerequisites
│   │       ├── k3s/                     # k3s install & config
│   │       ├── kubectl/                 # kubectl setup
│   │       ├── awx_operator/            # AWX Operator deployment
│   │       ├── awx/                     # AWX instance + PVCs
│   │       ├── ingress/                 # Traefik ingress
│   │       └── cert_manager/            # Optional Let's Encrypt TLS
│   └── playbook/                        # General-purpose automation roles
│       ├── add_hosts/
│       ├── apache/
│       ├── aws/
│       ├── common-server/
│       ├── common/
│       ├── crowdstrike/
│       ├── deploy_vm/
│       ├── docker/
│       ├── git/
│       ├── java/
│       ├── jboss/
│       ├── nginx/
│       ├── os_hardening/
│       ├── patching/
│       ├── remove_host/
│       ├── server-info/
│       └── ssh_hardening/
└── terraform/                           # Cloud infra provisioning
```

---

## Deployment Methods

### Method 1 — Deploy FROM the target server (git clone directly on server)

This is the simplest approach. Clone the repo onto the server that will run AWX,
then run Ansible locally — no SSH needed.

**Step 1: Clone the repo on the target server**

```bash
git clone <your-repo-url> /opt/iac
cd /opt/iac
```

**Step 2: Install Ansible**

```bash
pip3 install ansible kubernetes pyyaml --break-system-packages
```

**Step 3: Set localhost in inventory**

Edit `ansible/inventory/hosts.yml`:

```yaml
k3s_masters:
  hosts:
    awx-master-01:
      ansible_host: 127.0.0.1
      ansible_connection: local     # no SSH — runs directly on this machine
      ip: 192.168.1.10              # server's actual IP (used by k3s node binding)

k3s_workers:
  hosts: {}
```

**Step 4: Configure variables**

```bash
vi ansible/group_vars/all.yml
vi ansible/awx-deployment/awx_group_vars/all.yml
```

Minimum changes:
```yaml
awx_fqdn: awx.example.com          # your domain or server IP
awx_admin_password: "YourPassword" # change this
timezone: UTC                       # your timezone
```

**Step 5: Run**

```bash
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/awx-deployment/awx_site.yml -v
```

> **Note:** The user running Ansible must have sudo or be root.
> No SSH keys required when using `ansible_connection: local`.

---

### Method 2 — Deploy FROM a control machine (remote targets)

Use this when you manage multiple servers from a separate Ansible control node.



**Step 1: Install Ansible**

```bash
yum install git ansible python3-pip3
pip3 install ansible kubernetes pyyaml --break-system-packages
```
**Step 2: Clone the repo on your control machine**

```bash
git clone <your-repo-url> /opt/iac
cd /opt/iac
```

**Step 3: Set remote hosts in inventory**

Edit `ansible/inventory/hosts.yml`:

```yaml
all:
  vars:
    ansible_user: root
    ansible_ssh_private_key_file: ~/.ssh/id_rsa

k3s_masters:
  hosts:
    awx-master-01:
      ansible_host: 192.168.1.10   # target server IP
      ip: 192.168.1.10

k3s_workers:
  hosts: {}
```

**Step 4: Configure variables**

```bash
vi ansible/group_vars/all.yml
vi ansible/awx-deployment/awx_group_vars/all.yml
```

**Step 5: Test connectivity**

```bash
ansible -i ansible/inventory/hosts.yml all -m ping
```

**Step 6: Run**

```bash
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/awx-deployment/awx_site.yml -v
```

---

## Key Variables to Change Before Running

| File | Variable | Description |
|------|----------|-------------|
| `ansible/group_vars/all.yml` | `timezone` | Your server timezone (e.g. `Asia/Phnom_Penh`) |
| `ansible/group_vars/all.yml` | `domain_suffix` | Your domain (e.g. `example.com`) |
| `ansible/awx-deployment/awx_group_vars/all.yml` | `awx_fqdn` | AWX URL (e.g. `awx.example.com`) |
| `ansible/awx-deployment/awx_group_vars/all.yml` | `awx_admin_password` | AWX admin password |
| `ansible/inventory/hosts.yml` | `ansible_host` | Target server IP |
| `ansible/inventory/hosts.yml` | `ip` | Server IP used by k3s |

---

## Run Options

### Full deployment
```bash
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/awx-deployment/awx_site.yml -v
```

### Run only specific phases using tags
```bash
# System prerequisites only
ansible-playbook ... --tags common

# k3s install only
ansible-playbook ... --tags k3s

# AWX Operator only
ansible-playbook ... --tags awx_operator

# AWX instance only
ansible-playbook ... --tags awx

# Ingress only
ansible-playbook ... --tags ingress

# TLS / cert-manager only
ansible-playbook ... --tags cert_manager
```

### Dry-run (no changes applied)
```bash
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/awx-deployment/awx_site.yml --check -v
```

### Syntax check
```bash
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/awx-deployment/awx_site.yml --syntax-check
```

---

## Post-Deployment Verification

```bash
# Check cluster nodes
k3s kubectl get nodes

# Check all pods
k3s kubectl get pods -A

# Check AWX pods specifically
k3s kubectl get pods -n awx

# Check AWX instance status
k3s kubectl get awx -n awx

# Check storage
k3s kubectl get pvc -n awx

# Check ingress
k3s kubectl get ingress -n awx

# Get admin password
k3s kubectl get secret awx-admin-password \
  -n awx -o jsonpath='{.data.password}' | base64 -d
```

---

## Access AWX

After deployment, AWX is available at:

```
http://awx.example.com     # HTTP (default)
https://awx.example.com    # HTTPS (if TLS enabled)
```

If you don't have DNS set up, add a hosts entry on your local machine:

```bash
# Linux / Mac
echo "192.168.1.10  awx.example.com" | sudo tee -a /etc/hosts

# Windows (run as Administrator)
echo 192.168.1.10  awx.example.com >> C:\Windows\System32\drivers\etc\hosts
```

Or access directly via IP:
```
http://192.168.1.10
```

Login credentials:
- **Username:** `admin`
- **Password:** value of `awx_admin_password` in your group_vars

---

## General Automation — playbook/ roles

Because `ansible.cfg` sets `roles_path = ansible/playbook`, any playbook can
reference these roles by name directly without specifying a path:

```yaml
# example-playbook.yml
- hosts: all
  roles:
    - patching
    - os_hardening
    - ssh_hardening
    - docker
```

Run it with:
```bash
ansible-playbook -i ansible/inventory/hosts.yml example-playbook.yml -v
```

---

## Scaling

### Single-node → HA (3 masters)

Update `ansible/inventory/hosts.yml`:
```yaml
k3s_masters:
  hosts:
    awx-master-01:
      ansible_host: 192.168.1.10
      ip: 192.168.1.10
    awx-master-02:
      ansible_host: 192.168.1.11
      ip: 192.168.1.11
    awx-master-03:
      ansible_host: 192.168.1.12
      ip: 192.168.1.12
```

Re-run the playbook — it handles adding nodes idempotently.

### Add workers
```yaml
k3s_workers:
  hosts:
    awx-worker-01:
      ansible_host: 192.168.1.20
      ip: 192.168.1.20
```

---

## Troubleshooting

```bash
# Pods not starting
k3s kubectl get events -n awx
k3s kubectl describe pod -n awx <pod-name>
k3s kubectl logs -n awx <pod-name>

# Resource issues
k3s kubectl top nodes
k3s kubectl top pods -n awx

# Ingress not working
k3s kubectl get ingress -n awx -o yaml
k3s kubectl describe ingress awx-ingress -n awx

# Port-forward for local testing (bypasses ingress)
k3s kubectl port-forward svc/awx-service 8080:80 -n awx
# Then open: http://localhost:8080

# Database issues
k3s kubectl logs -n awx awx-postgres-0
k3s kubectl get pvc -n awx
```

---

## Backup

```bash
# Backup AWX database
k3s kubectl exec -n awx awx-postgres-0 -- \
  pg_dump -U awx awx > awx-backup-$(date +%Y%m%d).sql

# Backup secrets
k3s kubectl get secrets -n awx -o yaml > awx-secrets-backup.yaml
```