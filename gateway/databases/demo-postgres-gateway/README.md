# Demo PostgreSQL Gateway Manifests

This directory contains a minimal test setup for PostgreSQL external access through Envoy Gateway and Gateway API `TLSRoute`.

It creates:

- `demo-db` namespace.
- `postgres-gateway` Gateway with a TLS passthrough listener on port `5432`.
- TLS-enabled PostgreSQL 17 `StatefulSet`.
- Internal `ClusterIP` Service for Gateway routing.
- `TLSRoute` for `demo-pg.db.infrasnow.com`.
- Basic ingress NetworkPolicies.

Apply:

```sh
kubectl apply -k demo-postgres-gateway
```

Check status:

```sh
kubectl get gateway -n default postgres-gateway
kubectl get tlsroute -n demo-db demo-postgres
kubectl get pod,svc -n demo-db
```

Find the Envoy Gateway external address:

```sh
kubectl get svc -n envoy-gateway-system
```

Point `demo-pg.db.infrasnow.com` to the Envoy Gateway external address, then connect with direct TLS negotiation:

```sh
PGPASSWORD=demo-password psql "host=demo-pg.db.infrasnow.com port=5432 user=demo dbname=appdb sslmode=require sslnegotiation=direct"
```

Notes:

- This is a demo, not a production PostgreSQL deployment.
- The PostgreSQL pod generates a short-lived self-signed TLS certificate at startup.
- `TLSRoute` requires Gateway API experimental CRDs in many clusters. This demo uses `gateway.networking.k8s.io/v1alpha3`.
- `sslnegotiation=direct` is required so the client starts TLS immediately and Envoy Gateway can route by SNI.
- In Cloudflare, the database hostname must expose raw TCP `5432`. Use a DNS-only record pointing to the Gateway load balancer, or a TCP proxy product such as Cloudflare Spectrum. A normal proxied HTTP(S) Cloudflare record will not forward PostgreSQL.
