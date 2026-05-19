# Demo PostgreSQL Gateway Manifests

This directory contains a minimal test setup for PostgreSQL external access through Envoy Gateway and Gateway API `TLSRoute`.

It creates:

- `demo-db` namespace.
- `postgres-gateway` Gateway with a TLS passthrough listener on port `5432`.
- TLS-enabled PostgreSQL 17 `StatefulSet`.
- Internal `ClusterIP` Service for Gateway routing.
- `TLSRoute` for `demo-pg-1.db.infrasnow.com`.
- Basic ingress NetworkPolicies.

Apply:

```sh
kubectl apply -k demo-postgres-gateway
```

Check status:

```sh
kubectl get gateway -n default postgres-gateway
kubectl get tlsroute -n demo-db
kubectl get pod,svc -n demo-db
```

Find the Envoy Gateway external address:

```sh
kubectl get svc -n envoy-gateway-system
```

Point both database hostnames to the Envoy Gateway external address:

- `demo-pg-1.db.infrasnow.com`
- `demo-pg-2.db.infrasnow.com`

Then connect to each hostname with direct TLS negotiation:

```sh
PGPASSWORD=demo-password psql "host=demo-pg-1.db.infrasnow.com port=5432 user=demo dbname=appdb sslmode=require sslnegotiation=direct"
PGPASSWORD=demo-password psql "host=demo-pg-1.db.infrasnow.com port=5432 user=demo dbname=appdb sslmode=require sslnegotiation=direct"
```

To verify routing is going to different backends, compare the connected database and server address:

```sh
PGPASSWORD=demo-password psql "host=demo-pg.db-1.infrasnow.com port=5432 user=demo dbname=appdb sslmode=require sslnegotiation=direct" -c "select current_database(), inet_server_addr();"
PGPASSWORD=demo-password psql "host=demo-pg.db-2.infrasnow.com port=5432 user=demo dbname=appdb sslmode=require sslnegotiation=direct" -c "select current_database(), inet_server_addr();"
```

