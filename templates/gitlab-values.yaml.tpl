global:
  hosts:
    domain: ${DOMAIN}
  ingress:
    tls:
      enabled: true
      secretName: gitlab-tls
  edition: ee
  initialRootPassword:
    password: ${GITLAB_ROOT_PASSWORD}

postgresql:
  persistence:
    enabled: true
    hostPath: ${PV_GITLAB_POSTGRES}
    size: 10Gi

redis:
  persistence:
    enabled: true
    hostPath: ${PV_GITLAB_GITALY}
    size: 5Gi

gitlab:
  logs:
    persistence:
      enabled: true
      hostPath: ${PV_GITLAB_LOGS}
      size: 10Gi