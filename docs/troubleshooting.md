# Troubleshooting

## AWX web not accessible after deploy

```bash
# Check all containers are running
docker compose ps

# Check awx-web logs
docker compose logs awx-web --tail=50

# AWX takes 3-5 min on first start (running Django migrations)
# Watch for this line in logs:
docker compose logs -f awx-web | grep -E "Listening|migration|error"
```

---

## PostgreSQL connection errors

```bash
# Test postgres directly
docker compose exec postgres pg_isready -U awx -d awx

# Check postgres logs
docker compose logs postgres --tail=30

# Connect to DB manually
docker compose exec postgres psql -U awx -d awx -c '\dt'
```

---

## AWX shows "Error: Server Error"

Usually means migrations haven't finished or SECRET_KEY mismatch.

```bash
# Check if awx-web and awx-task have same SECRET_KEY
docker compose exec awx-web env | grep SECRET_KEY
docker compose exec awx-task env | grep SECRET_KEY

# Run migrations manually
docker compose exec awx-task awx-manage migrate

# Check for errors
docker compose exec awx-task awx-manage check
```

---

## Reset admin password

```bash
docker compose exec awx-task awx-manage update_password \
  --username=admin \
  --password=NewPassword123!
```

---

## Full reset (start fresh)

```bash
./scripts/cleanup.sh --volumes
./scripts/deploy.sh
```

---

## Useful commands

```bash
# View all logs
docker compose logs -f

# View specific service logs
docker compose logs -f awx-web
docker compose logs -f awx-task
docker compose logs -f postgres

# Restart single service
docker compose restart awx-web

# Check resource usage
docker stats

# Run AWX management commands
docker compose exec awx-task awx-manage shell
docker compose exec awx-task awx-manage list_instances
docker compose exec awx-task awx-manage inventory_import \
  --inventory-name="My Inventory" \
  --source=/var/lib/awx/projects/my-project/inventories/hosts.yml
```
