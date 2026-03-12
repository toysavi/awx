# Secrets Management

## Overview

This project follows these principles for secrets management:

1. **Zero secrets in Git** — `.env` files, passwords, tokens are never committed
2. **Kubernetes Secrets** — all sensitive values stored as K8s Secrets
3. **Environment-specific** — each environment has isolated secrets
4. **CI/CD injection** — GitHub Actions Secrets → K8s Secrets at deploy time

## Secret Files (gitignored)

The following files contain real secrets and are listed in `.gitignore`:

```
k8s/overlays/dev/secrets.env
k8s/overlays/staging/secrets.env
k8s/overlays/prod/secrets.env
```

Copy the example and fill in values:
```bash
cp k8s/base/secrets.env.example k8s/overlays/dev/secrets.env
```

## Kubernetes Secrets Created

| Secret Name | Keys | Used By |
|------------|------|---------|
| `awx-postgres-secret` | POSTGRES_PASSWORD, POSTGRES_DB, POSTGRES_USER | PostgreSQL StatefulSet |
| `awx-postgres-configuration` | host, port, database, username, password | AWX Operator |
| `awx-admin-password` | password | AWX initial admin login |

## GitHub Actions Secrets

Configure these in `Settings → Secrets and variables → Actions`:

| Secret Name | Description |
|------------|-------------|
| `KUBECONFIG_DEV` | base64-encoded kubeconfig for dev cluster |
| `KUBECONFIG_STAGING` | base64-encoded kubeconfig for staging |
| `KUBECONFIG_PROD` | base64-encoded kubeconfig for prod |
| `POSTGRES_PASSWORD_DEV` | PostgreSQL password for dev |
| `POSTGRES_PASSWORD_STAGING` | PostgreSQL password for staging |
| `POSTGRES_PASSWORD_PROD` | PostgreSQL password for prod |
| `AWX_ADMIN_PASSWORD_DEV` | AWX admin password for dev |
| `AWX_ADMIN_PASSWORD_STAGING` | AWX admin password for staging |
| `AWX_ADMIN_PASSWORD_PROD` | AWX admin password for prod |

### Encode kubeconfig for GitHub Secret:
```bash
cat ~/.kube/config | base64 -w 0
```

## Advanced: HashiCorp Vault Integration

For enterprise deployments, replace the `secretGenerator` in kustomization with
Vault Agent Injector or External Secrets Operator:

```yaml
# Using External Secrets Operator
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: awx-postgres-secret
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  target:
    name: awx-postgres-secret
  data:
    - secretKey: POSTGRES_PASSWORD
      remoteRef:
        key: secret/awx/postgres
        property: password
```

## Password Rotation

To rotate the PostgreSQL password:
1. Update the GitHub Actions Secret
2. Re-run the deploy pipeline
3. kustomize will update the K8s Secret
4. Restart the PostgreSQL pod: `kubectl rollout restart statefulset/awx-postgres -n awx-prod`
5. Restart AWX: `kubectl rollout restart deployment/awx -n awx-prod`
