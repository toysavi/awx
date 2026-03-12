# Troubleshooting

## Common Issues

### AWX Operator not creating AWX pods

**Symptom:** `kubectl get pods -n awx-dev` shows only postgres, no AWX pods.

**Check operator logs:**
```bash
kubectl logs -n awx-operator-system \
  deployment/awx-operator-controller-manager \
  -c manager --tail=50
```

**Common causes:**
- Missing `awx-postgres-configuration` secret
- AWX CR has validation errors
- Insufficient resources on node

---

### PostgreSQL pod stuck in `Pending`

**Symptom:** `kubectl get pods -n awx-dev` shows postgres in Pending state.

**Check events:**
```bash
kubectl describe pod -n awx-dev -l app=awx-postgres
```

**Common causes:**
- No PersistentVolume available → check storage class
- Node doesn't have enough resources

**Fix for k3s (local-path provisioner):**
```bash
kubectl get storageclass
# Should show: local-path (default)
```

---

### AWX web UI not accessible

**Port-forward test:**
```bash
kubectl port-forward svc/awx-service -n awx-dev 8080:80
curl http://localhost:8080/api/v2/ping/
```

**Check AWX pod logs:**
```bash
kubectl logs -n awx-dev deployment/awx -c awx-web --tail=50
kubectl logs -n awx-dev deployment/awx -c awx-task --tail=50
```

---

### Database connection errors in AWX

**Symptom:** AWX logs show `django.db.utils.OperationalError: could not connect to server`

**Verify the secret:**
```bash
kubectl get secret awx-postgres-configuration -n awx-dev -o yaml
```

**Test DB connection from AWX pod:**
```bash
kubectl exec -n awx-dev deployment/awx -c awx-task -- \
  psql postgresql://awx:PASSWORD@awx-postgres.awx-dev.svc.cluster.local/awx -c '\l'
```

---

### kustomize build fails with "no such file: secrets.env"

**Fix:**
```bash
cp k8s/base/secrets.env.example k8s/overlays/dev/secrets.env
# Edit the file with real values
```

---

## Useful Commands

```bash
# Watch all pods in namespace
kubectl get pods -n awx-dev -w

# Get AWX admin password
kubectl get secret awx-admin-password -n awx-dev \
  -o jsonpath='{.data.password}' | base64 -d

# Restart AWX
kubectl rollout restart deployment/awx -n awx-dev

# Restart PostgreSQL
kubectl rollout restart statefulset/awx-postgres -n awx-dev

# Check AWX CR status
kubectl describe awx awx -n awx-dev

# View all events
kubectl get events -n awx-dev --sort-by='.lastTimestamp'

# Exec into AWX task container
kubectl exec -it -n awx-dev deployment/awx -c awx-task -- bash

# Exec into PostgreSQL
kubectl exec -it -n awx-dev statefulset/awx-postgres -- \
  psql -U awx -d awx
```
