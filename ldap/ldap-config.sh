global:
  appConfig:
    ldap:
      servers:
        main:
          label: "LDAP"
          host: "${LDAP_HOST}"
          port: ${LDAP_PORT}
          uid: "uid"
          bind_dn: "${LDAP_BIND_DN}"
          password: "${LDAP_BIND_PASSWORD}"
          base: "${LDAP_BASE_DN}"