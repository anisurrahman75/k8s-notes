Current architecture:


* Kubernetes Gateway API
* Envoy Gateway
* TLSRoute
* TLS passthrough
* PostgreSQL StatefulSet
* PostgreSQL TLS enabled
* SNI hostname routing


Client
→ Envoy Gateway LoadBalancer
→ Envoy Gateway
→ TLSRoute (TLS passthrough)
→ PostgreSQL Service
→ PostgreSQL Pod

Current state:

* PostgreSQL currently generates self-signed certificates dynamically using an initContainer.
* TLSRoute hostnames use:

    * demo-pg-1.db.infrasnow.com
* Gateway listener:

    * protocol: TLS
    * tls.mode: Passthrough
* Cloudflare is used for DNS.
* cert-manager is already installed in the cluster.
* I want to migrate from self-signed certificates to real Let's Encrypt wildcard certificates.
* I want to keep TLS passthrough architecture.
* PostgreSQL itself should still terminate TLS.
* I want production-style manifests.

Your task:
Refactor my manifests and architecture to use:

* cert-manager
* Let's Encrypt
* Cloudflare DNS-01 challenge
* wildcard certificate:

    * *.db.infrasnow.com

Requirements:

1. Remove self-signed certificate generation initContainer completely.
2. Create proper ClusterIssuer using Let's Encrypt production endpoint.
3. Use Cloudflare API token Secret for DNS-01 challenge.
4. Create wildcard Certificate resource.
5. Mount generated TLS secret into PostgreSQL pod.
6. Ensure PostgreSQL TLS works correctly with mounted certs.
7. Ensure PostgreSQL key permissions are correct.
8. Keep Gateway TLS passthrough mode.
9. Keep TLSRoute architecture.
10. Keep SNI hostname routing.
11. Use production-grade Kubernetes manifests.
12. Explain each manifest briefly.
13. Include:

    * ClusterIssuer
    * Secret example for Cloudflare token
    * Certificate
    * Updated StatefulSet
14. Ensure the setup supports:

    * sslmode=verify-full
    * sslnegotiation=direct
15. Explain how to verify:

    * certificate issuance
    * secret generation
    * openssl validation
    * psql connection
16. Explain any PostgreSQL TLS caveats with cert-manager.
17. Explain why TLS passthrough still works with Let's Encrypt certificates.
18. Explain how wildcard certificates work with PostgreSQL SNI routing.
19. Assume:

    * Gateway API v1
    * TLSRoute v1alpha3
    * Envoy Gateway
    * PostgreSQL 17
20. Keep manifests clean and production-oriented.

My current Gateway:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: postgres-gateway
  namespace: default
spec:
  gatewayClassName: eg
  listeners:
    - name: postgres-tls
      hostname: "*.db.infrasnow.com"
      port: 5432
      protocol: TLS
      tls:
        mode: Passthrough
      allowedRoutes:
        namespaces:
          from: Selector
          selector:
            matchLabels:
              dbaas.infrasnow.com/routes-allowed: "true"
```

My current TLSRoute:

```yaml
apiVersion: gateway.networking.k8s.io/v1alpha3
kind: TLSRoute
metadata:
  name: demo-postgres-1
  namespace: demo-db
spec:
  parentRefs:
    - name: postgres-gateway
      namespace: default
      sectionName: postgres-tls
  hostnames:
    - demo-pg-1.db.infrasnow.com
  rules:
    - backendRefs:
        - name: demo-postgres-1
          port: 5432
```

My PostgreSQL currently enables TLS with:

```yaml
args:
  - -c
  - ssl=on
  - -c
  - ssl_cert_file=/etc/postgres-tls/tls.crt
  - -c
  - ssl_key_file=/etc/postgres-tls/tls.key
```

Generate the complete production-style solution.
