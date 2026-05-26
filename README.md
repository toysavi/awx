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

## Quick start — deploy AWX

```bash
# 1. Edit inventory
vi ansible/inventory/hosts.yml

# 2. Set variables
vi ansible/group_vars/all.yml
vi ansible/awx-deployment/awx_group_vars/all.yml

# 3. Run
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/awx-deployment/awx_site.yml -v

# 4. Access AWX
# http://awx.example.com  (admin / your-password)
```

## Quick start — general automation

Because `ansible.cfg` sets `roles_path = ansible/playbook`, any playbook can
reference these roles by name directly:

```yaml
- hosts: all
  roles:
    - patching
    - os_hardening
    - ssh_hardening
```

## Tags

Run only specific phases of AWX deployment:

```bash
ansible-playbook ... --tags k3s          # k3s install only
ansible-playbook ... --tags awx          # AWX instance only
ansible-playbook ... --tags ingress      # Ingress only
```
