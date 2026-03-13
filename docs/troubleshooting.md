# Troubleshooting Guide

## Quick Reference

```bash
# All AWX pods
kubectl get pods -n awx

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

# All ingress routes
kubectl get ingressroute -A

# All services
kubectl get svc -A
```

---

## Common Issues

### kubectl: connection refused (localhost:8080)

```
The connection to the server localhost:8080 was refused
```

**Fix:**
```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> ~/.bashrc
source ~/.bashrc
```

---

### Traefik LoadBalancer `<pending>`

**Fix:** Re-enable servicelb (do not use `--disable=servicelb` in k3s install):
```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --write-kubeconfig-mode=644" sh -
```

---

### AWX pod stuck in `Init:0/2`

Database migrations are still running. Wait and watch:
```bash
kubectl get pods -n awx -w
kubectl logs -n awx -l job-name -f
```

---

### AWX: 502 Bad Gateway

AWX is still starting up. Check:
```bash
kubectl get pods -n awx
kubectl logs -n awx -l app.kubernetes.io/name=awx-web --tail=50
```

---

### AWX Operator Helm repo 404

The repo URL changed. Use the correct one:
```bash
helm repo add awx-operator https://ansible-community.github.io/awx-operator-helm/
```

---

### Rancher certificate warning in browser

Expected with self-signed cert (nip.io). Click **Advanced → Proceed**.

For Let's Encrypt (real domain):
```bash
helm upgrade rancher rancher-stable/rancher \
  --namespace cattle-system \
  --set hostname=rancher.yourdomain.com \
  --set ingress.tls.source=letsEncrypt \
  --set letsEncrypt.email=admin@yourdomain.com \
  --reuse-values
```

---

### Traefik dashboard returns 404

Trailing slash is required:
```
https://traefik.YOUR_IP.nip.io/dashboard/   ✅
https://traefik.YOUR_IP.nip.io/dashboard    ❌
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

### Full reset

```bash
./scripts/uninstall.sh --all --data
./scripts/install.sh
```

---

## Useful Commands

```bash
# Check all resources in awx namespace
kubectl get all -n awx

# Check PVCs (persistent data)
kubectl get pvc -n awx

# Check Traefik middleware
kubectl get middleware -A

# Restart AWX web pod
kubectl rollout restart deployment/awx-web -n awx

# Restart Traefik
kubectl rollout restart deployment/traefik -n kube-system

# Check cert-manager certificates
kubectl get certificates -A
kubectl describe certificate -n awx

# Check k3s service
systemctl status k3s
journalctl -u k3s -f
```
