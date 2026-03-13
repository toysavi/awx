# AWX Configuration as Code

Configure all AWX resources declaratively using the `awx.awx` Ansible collection.

## Prerequisites

```bash
pip3 install awxkit ansible
ansible-galaxy collection install awx.awx
```

## Environment Setup

```bash
export CONTROLLER_HOST=https://awx.YOUR_IP.nip.io
export CONTROLLER_USERNAME=admin
export CONTROLLER_PASSWORD=$(kubectl get secret awx-admin-password -n awx \
  -o jsonpath="{.data.password}" | base64 -d)
export CONTROLLER_VERIFY_SSL=false
```

## Apply All Config

```bash
cd awx-config/scripts
bash import.sh
```

## Apply Specific Sections

```bash
ansible-playbook awx-config/scripts/configure-all.yml --tags organizations
ansible-playbook awx-config/scripts/configure-all.yml --tags credentials
ansible-playbook awx-config/scripts/configure-all.yml --tags inventories
ansible-playbook awx-config/scripts/configure-all.yml --tags projects
ansible-playbook awx-config/scripts/configure-all.yml --tags templates
ansible-playbook awx-config/scripts/configure-all.yml --tags notifications
ansible-playbook awx-config/scripts/configure-all.yml --tags schedules
```

## Export Current Config

```bash
bash awx-config/scripts/export.sh
```

## Configuration Files

| File | Description |
|------|-------------|
| `organizations/organizations.yml` | Orgs, Teams, Users |
| `credentials/credentials.yml` | SSH, Git, Azure, Vault |
| `inventories/inventories.yml` | Inventories, Hosts, Groups |
| `projects/projects.yml` | Git-linked projects |
| `templates/templates.yml` | Job templates |
| `workflows/workflows.yml` | Workflow pipelines |
| `notifications/notifications.yml` | Telegram, Email, Slack |
| `schedules/schedules.yml` | Scheduled jobs |

## Customisation

Before applying, replace all placeholders:

| Placeholder | Replace with |
|-------------|-------------|
| `REPLACE_WITH_ACTUAL_PRIVATE_KEY` | Your SSH private key |
| `REPLACE_WITH_GITHUB_TOKEN` | GitHub personal access token |
| `REPLACE_BOT_TOKEN` | Telegram bot token |
| `REPLACE_CHAT_ID` | Telegram chat ID |
| `REPLACE_WITH_SMTP_PASSWORD` | SMTP password |
| `REPLACE_WITH_SLACK_BOT_TOKEN` | Slack bot token |
| `REPLACE_WITH_AZURE_*` | Azure service principal details |
| `yourorg` | Your GitHub organization name |
| `yourdomain.com` | Your actual domain |
