# Troubleshooting Guide

## Common Issues

---

### kubectl: connection refused (localhost:8080)

**Symptom:**
```
The connection to the server localhost:8080 was refused
```

**Fix:**
```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> ~/.bashrc
```

---

### Traefik LoadBalancer stuck at `<pending>`

**Symptom:**
```
traefik   LoadBalancer   10.43.x.x   <pending>   80:31xxx/TCP,443:30xxx/TCP
```

**Fix:** Ensure servicelb is enabled (not disabled in k3s install):
```bash
# Reinstall k3s without --disable=servicelb
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --write-kubeconfig-mode=644" sh -
```

---

### AWX pod stuck in `Init:0/2`

**Symptom:** `awx-task` shows `Init:0/2` for a long time

**Cause:** Database migrations running in `awx-migration` pod

**Fix:** Wait for migrations to complete:
```bash
kubectl logs -n awx -l job-name -f
kubectl get pods -n awx -w
```

---

### AWX: SECRET_KEY is empty

**Symptom:**
```
ImproperlyConfigured: The SECRET_KEY setting must not be empty
```

**Fix:** SECRET_KEY must be in `/etc/tower/settings.py`, not just env vars:
```bash
# Check the secret exists
kubectl get secret awx-secret-key -n awx
```

---

### Redis: Permission denied on Unix socket

**Symptom:**
```
Failed opening Unix socket: bind: Permission denied
```

**Fix:** Use a host bind mount with `chmod 777`:
```bash
mkdir -p /awx/redis-socket
chmod 777 /awx/redis-socket
```

---

### Rancher: Certificate warning in browser

**Symptom:** Browser shows "Your connection is not private"

**Fix:** This is expected with self-signed certs. Click **Advanced → Proceed**.

For production, use a real domain with Let's Encrypt:
```bash
helm upgrade rancher rancher-stable/rancher \
  --namespace cattle-system \
  --set hostname=rancher.yourdomain.com \
  --set ingress.tls.source=letsEncrypt \
  --set letsEncrypt.email=admin@yourdomain.com
```

---

### AWX Operator Helm repo 404

**Symptom:**
```
failed to fetch https://ansible.github.io/awx-operator/index.yaml: 404 Not Found
```

**Fix:** The repo moved. Use the correct URL:
```bash
helm repo add awx-operator https://ansible-community.github.io/awx-operator-helm/
```

---

### AWX web shows "Bad Gateway"

**Symptom:** 502 Bad Gateway when accessing AWX URL

**Fix:** AWX is still starting. Wait and check:
```bash
kubectl get pods -n awx
kubectl logs -n awx -l app.kubernetes.io/name=awx-web -f
```

---

### Get AWX admin password

```bash
kubectl get secret awx-admin-password -n awx \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

---

### Reset AWX admin password

```bash
kubectl exec -n awx deployment/awx-web -- \
  awx-manage update_password --username=admin --password=NewPassword123!
```

---

### Full reset (nuclear option)

```bash
./scripts/uninstall.sh --all --data
./scripts/install.sh
```

---

## Useful Commands

```bash
# Watch all AWX pods
kubectl get pods -n awx -w

# AWX web logs
kubectl logs -n awx -l app.kubernetes.io/name=awx-web -f

# AWX task logs
kubectl logs -n awx -l app.kubernetes.io/name=awx-task -f

# AWX operator logs
kubectl logs -n awx -l control-plane=controller-manager -f

# Rancher logs
kubectl logs -n cattle-system -l app=rancher -f

# Traefik logs
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik -f

# Check ingress routes
kubectl get ingress -n awx
kubectl get ingress -n cattle-system

# Check PVCs
kubectl get pvc -n awx

# Check all resources in awx namespace
kubectl get all -n awx
```
