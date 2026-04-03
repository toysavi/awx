apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: awx
  namespace: argocd
spec:
  project: default
  source:
    repoURL: 'https://github.com/your-org/awx-helm.git'
    targetRevision: main
    path: charts/awx
    helm:
      valueFiles:
        - values.yaml
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: awx
  syncPolicy:
    automated:
      prune: true
      selfHeal: true