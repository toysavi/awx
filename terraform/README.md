# Terraform

Provision cloud infrastructure before running Ansible.

## Typical layout

```
terraform/
├── main.tf          # Provider config, resources
├── variables.tf     # Input variables
├── outputs.tf       # Outputs (IPs, DNS) passed to Ansible inventory
└── modules/
    ├── vpc/
    ├── ec2/
    └── dns/
```

## Usage

```bash
terraform init
terraform plan
terraform apply
# Copy outputs to ansible/inventory/hosts.yml
```
