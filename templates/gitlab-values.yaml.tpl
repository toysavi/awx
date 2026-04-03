global:
  hosts:
    domain: ${DOMAIN}
    externalIP: ""
  ingress:
    configureCertmanager: false
    tls:
      enabled: true
  edition: ee

gitlab:
  webservice:
    ingress:
      tls:
        secretName: gitlab-tls

global:
  initialRootPassword:
    password: ${GITLAB_ROOT_PASSWORD}