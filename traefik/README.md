# Traefik Configuration

Traefik is the built-in ingress controller in k3s.

## Quick Setup

```bash
./scripts/setup-traefik.sh
```

## What's Configured

| File | Purpose |
|------|---------|
| `config/traefik-config.yaml` | TLS 1.2+, entrypoints, logs, HTTP→HTTPS redirect |
| `config/ingressroutes.yaml` | AWX + Rancher routes with middleware |
| `middleware/middleware.yaml` | Security headers, rate limiting, basic auth |
| `dashboard/dashboard-ingress.yaml` | Traefik dashboard (password protected) |
| `tls/letsencrypt.yaml` | Let's Encrypt ACME (real domains only) |

## Access

| Service | URL |
|---------|-----|
| Rancher | `https://YOUR_IP.nip.io` |
| AWX | `https://awx.YOUR_IP.nip.io` |
| Traefik Dashboard | `https://traefik.YOUR_IP.nip.io/dashboard/` |

## For Real Domains (Let's Encrypt)

1. Point your domain DNS to your server IP
2. Edit `traefik/tls/letsencrypt.yaml` — set your email and domain
3. Apply: `kubectl apply -f traefik/tls/letsencrypt.yaml`
4. Update AWX: `kubectl edit awx awx -n awx` → change hostname
5. Update Rancher:
```bash
helm upgrade rancher rancher-stable/rancher \
  --namespace cattle-system \
  --set hostname=rancher.yourdomain.com \
  --set ingress.tls.source=letsEncrypt \
  --set letsEncrypt.email=admin@yourdomain.com \
  --reuse-values
```
