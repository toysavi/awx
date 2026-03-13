# AWX Docker Compose Deployment

Production-ready AWX (Ansible Tower open-source) deployment using Docker Compose
with PostgreSQL and Redis on Ubuntu Linux.

## Architecture

```
┌─────────────────────────────────────────────────┐
│                  Docker Host (Ubuntu)            │
│                                                 │
│  ┌──────────┐   ┌──────────┐   ┌─────────────┐ │
│  │ awx-web  │   │ awx-task │   │  awx-redis  │ │
│  │ :8052    │   │          │   │  :6379      │ │
│  └────┬─────┘   └────┬─────┘   └─────────────┘ │
│       │              │                          │
│  ┌────▼──────────────▼──────┐                  │
│  │      awx-postgres        │                  │
│  │         :5432            │                  │
│  └──────────────────────────┘                  │
│                                                 │
│  Port 80 → awx-web:8052                        │
└─────────────────────────────────────────────────┘
```

## Requirements

- Ubuntu 22.04+ server
- Minimum: 4 CPU, 8GB RAM, 40GB disk
- Docker Engine 24+
- Docker Compose plugin v2+

## Quick Start

### 1. Clone repository
```bash
git clone https://github.com/YOUR_ORG/awx-docker.git
cd awx-docker
```

### 2. Configure environment
```bash
cp .env.example .env
nano .env   # Set your passwords
```

### 3. Deploy
```bash
chmod +x scripts/*.sh
./scripts/deploy.sh
```

### 4. Access AWX
```
URL:      http://<YOUR_SERVER_IP>
Username: admin
Password: (value of AWX_ADMIN_PASSWORD in .env)
```

## Environment Support

| File | Purpose |
|------|---------|
| `.env` | Local/dev overrides (gitignored) |
| `.env.example` | Template with all variables |
| `envs/dev.env` | Dev defaults |
| `envs/staging.env` | Staging defaults |
| `envs/prod.env` | Production defaults |

Deploy to specific environment:
```bash
./scripts/deploy.sh dev
./scripts/deploy.sh staging
./scripts/deploy.sh prod
```

## Repository Structure

```
awx-docker/
├── README.md
├── docker-compose.yml          # Main compose file
├── docker-compose.override.yml # Local dev overrides
├── .env.example                # Environment variable template
├── envs/
│   ├── dev.env                 # Dev environment config
│   ├── staging.env             # Staging config
│   └── prod.env                # Production config
├── awx/
│   └── settings.py             # AWX application settings
├── postgres/
│   └── init.sql                # DB initialization
├── nginx/
│   └── awx.conf                # Nginx reverse proxy config
├── ansible/
│   ├── inventories/
│   └── playbooks/
├── scripts/
│   ├── deploy.sh               # Main deploy script
│   ├── cleanup.sh              # Full cleanup script
│   └── healthcheck.sh          # Post-deploy health check
├── docs/
│   ├── secrets-management.md
│   └── troubleshooting.md
└── .github/
    └── workflows/
        ├── deploy.yml
        └── validate.yml
```

## Common Commands

```bash
# Start all services
docker compose up -d

# View logs
docker compose logs -f
docker compose logs -f awx-web
docker compose logs -f awx-task

# Stop all services
docker compose down

# Stop and remove volumes (full reset)
docker compose down -v

# Restart a single service
docker compose restart awx-web

# Check status
docker compose ps

# Run AWX management commands
docker compose exec awx-task awx-manage check

# Backup database
./scripts/backup.sh

# Update AWX version
# Edit AWX_VERSION in .env, then:
./scripts/deploy.sh --update
```

## Updating AWX

Edit `AWX_VERSION` in your `.env` file:
```bash
AWX_VERSION=24.6.1
```

Then run:
```bash
./scripts/deploy.sh --update
```
