# PostgreSQL TLS Termination with PgBouncer

Envoy Gateway routes PostgreSQL traffic by SNI hostname. PgBouncer handles TLS termination and the PostgreSQL protocol. PostgreSQL runs without SSL.

## Architecture

```
Client (sslnegotiation=direct sslmode=verify-full)
  │ PostgreSQL SSLRequest skipped (direct TLS)
  │ TLS ClientHello with SNI: demo-pg-1.db.infrasnow.com
  ▼
Envoy Gateway (TLS Passthrough, port 5432)
  │ routes by SNI hostname via TLSRoute
  │ forwards raw TCP
  ▼
PgBouncer (handles TLS + PostgreSQL protocol)
  │ responds to PostgreSQL startup message
  │ connection pooling (transaction mode)
  │ routes by database name to PostgreSQL backend
  ▼
PostgreSQL (ssl=off)
```

## Why sslnegotiation=direct is required

PostgreSQL's standard SSL flow sends an 8-byte SSLRequest message before TLS starts. This message has no SNI hostname. Envoy Gateway needs SNI to route, so it can't forward the SSLRequest.

`sslnegotiation=direct` skips the SSLRequest and starts TLS immediately with SNI, which Envoy can route.

```
Standard PostgreSQL SSL:
  Client → SSLRequest (no SNI) → Gateway → can't route → connection closed

Direct SSL:
  Client → ClientHello (has SNI) → Gateway → routes by SNI → PgBouncer → TLS → PostgreSQL
```

## What gets created

- `demo-db` namespace
- `letsencrypt-prod` ClusterIssuer (commented out — already exists in cluster)
- `pg-wildcard-cert` Certificate — Let's Encrypt wildcard cert in `demo-db`
- `postgres-gateway` Gateway — TLS Passthrough on port 5432
- `BackendTrafficPolicy` — backend connection settings
- Two PostgreSQL 17 StatefulSets with `ssl=off`
- Two TLSRoute resources with hostname-based routing
- PgBouncer Deployment (2 replicas) — handles TLS + PostgreSQL protocol + connection pooling
- PgBouncer Service — ClusterIP

## Database routing

PgBouncer routes by database name:

| Client connects to | PgBouncer routes to |
|---|---|
| `dbname=appdb_1` | `demo-postgres-1` (PostgreSQL instance 1) |
| `dbname=appdb_2` | `demo-postgres-2` (PostgreSQL instance 2) |

## Prerequisites

- Envoy Gateway installed
- cert-manager installed
- Cloudflare DNS with API token
- Gateway API CRDs (v1 + v1alpha3 for TLSRoute)

## Apply

```sh
kubectl kustomize gateway/databases/demo-postgres-gateway/tls-termination | kubectl apply -f -
```

## Verify

### Certificate

```sh
kubectl get certificate -n demo-db pg-wildcard-cert
kubectl get secret -n demo-db pg-wildcard-tls
```

Expected: `Ready=True`

### Gateway

```sh
kubectl get gateway -n default postgres-gateway
```

Expected: `Programmed=True`

### TLSRoute

```sh
kubectl get tlsroute -n demo-db
```

Expected: `Accepted=True`

### PgBouncer

```sh
kubectl get pods -n demo-db -l app.kubernetes.io/name=pgbouncer
kubectl get svc -n demo-db pgbouncer
```

### TLS handshake

```sh
openssl s_client \
  -connect demo-pg-1.db.infrasnow.com:5432 \
  -servername demo-pg-1.db.infrasnow.com
```

Expected: Let's Encrypt wildcard certificate `*.db.infrasnow.com`

## Connect

### psql — sslmode=verify-full (recommended)

```sh
PGPASSWORD=demo-password psql \
  "host=demo-pg-1.db.infrasnow.com port=5432 user=demo dbname=appdb_1 sslmode=verify-full sslnegotiation=direct sslrootcert=system"
```

### psql — sslmode=require

```sh
PGPASSWORD=demo-password psql \
  "host=demo-pg-1.db.infrasnow.com port=5432 user=demo dbname=appdb_1 sslmode=require sslnegotiation=direct"
```

### Verify routing to different backends

```sh
PGPASSWORD=demo-password psql \
  "host=demo-pg-1.db.infrasnow.com port=5432 user=demo dbname=appdb_1 sslmode=require sslnegotiation=direct" \
  -c "select current_database(), inet_server_addr();"

PGPASSWORD=demo-password psql \
  "host=demo-pg-2.db.infrasnow.com port=5432 user=demo dbname=appdb_2 sslmode=require sslnegotiation=direct" \
  -c "select current_database(), inet_server_addr();"
```

Each returns a different `inet_server_addr()`.

### JDBC

```
jdbc:postgresql://demo-pg-1.db.infrasnow.com:5432/appdb_1?sslmode=verify-full&sslnegotiation=direct
```

### Connection string (URI)

```
postgresql://demo:demo-password@demo-pg-1.db.infrasnow.com:5432/appdb_1?sslmode=verify-full&sslnegotiation=direct
```

## Comparison: Three architectures

| | TLS Passthrough (no PgBouncer) | TLS Termination at Gateway | TLS Passthrough + PgBouncer (this) |
|---|---|---|---|
| Gateway mode | Passthrough | Terminate | Passthrough |
| TLS terminated at | PostgreSQL pod | Gateway | PgBouncer |
| PostgreSQL SSL | `ssl=on` | `ssl=off` | `ssl=off` |
| Certificate | self-signed or per-pod | wildcard at Gateway | wildcard at PgBouncer |
| SNI routing | yes | yes | yes |
| `sslnegotiation=direct` | required | required | required |
| `sslmode=verify-full` | requires custom CA | works with system CA | works with system CA |
| Connection pooling | no | no | yes (PgBouncer) |
| Protocol awareness | no | no | yes (PgBouncer) |
| Client compatibility | PostgreSQL 17+ | PostgreSQL 17+ | PostgreSQL 17+ |

## Key files

| File | Purpose |
|---|---|
| `04-gateway.yaml` | Gateway (TLS Passthrough) + BackendTrafficPolicy |
| `03-wildcard-certificate.yaml` | cert-manager Certificate for `*.db.infrasnow.com` in `demo-db` |
| `05-demo-pg-1.yaml` | PostgreSQL StatefulSet + TLSRoute → PgBouncer |
| `06-demo-pg-2.yaml` | PostgreSQL StatefulSet + TLSRoute → PgBouncer |
| `07-pgbouncer.yaml` | PgBouncer (TLS + PostgreSQL protocol + pooling) |

## Troubleshooting

| Problem | Cause |
|---|---|
| `server closed connection unexpectedly` | Missing `sslnegotiation=direct` |
| `ALPN protocol negotiation extension` error | Missing `sslnegotiation=direct` |
| `root certificate file does not exist` | Add `sslrootcert=system` |
| `filter_chain_not_found` in Envoy logs | SNI not present (SSLRequest has no SNI) |
| TLSRoute not accepted | Listener name mismatch |
| PgBouncer `bouncer config error` | Check `auth_type` and database config |
| Certificate not ready | Cloudflare API token wrong |

## Notes

- `sslnegotiation=direct` is a PostgreSQL 17+ feature. Older clients, JDBC drivers, ORMs, and tools that don't support it cannot connect through the Gateway.
- For clients that don't support `sslnegotiation=direct`, expose PgBouncer directly via a LoadBalancer Service (bypass Gateway) or use a custom Envoy filter.
- PgBouncer `auth_type = any` accepts any user/password. For production, use `auth_type = md5` with a proper userlist or `auth_query`.
- PgBouncer `pool_mode = transaction` is recommended for most workloads. Use `session` mode if your application uses prepared statements or session-level settings.
