# Standard PostgreSQL Clients via Envoy Gateway TCPRoute + PgBouncer

This variant is the working design for normal PostgreSQL clients.

It does **not** terminate TLS at Envoy Gateway. Instead:

- Envoy Gateway accepts raw TCP on port `5432`
- `TCPRoute` forwards every connection to PgBouncer
- PgBouncer answers PostgreSQL `SSLRequest`
- PgBouncer terminates TLS with a wildcard Let's Encrypt certificate
- PgBouncer routes to the correct PostgreSQL backend by `dbname`

That is the critical difference from the earlier `TLSRoute` design: standard PostgreSQL clients start with a plaintext `SSLRequest`, so a generic TLS listener at the Gateway cannot be the first TLS endpoint.

## Architecture

```text
Client (standard PostgreSQL SSL negotiation)
  │
  │ 1. TCP connect
  │ 2. SSLRequest
  ▼
Envoy Gateway (TCP listener, port 5432)
  │
  │ TCPRoute
  ▼
PgBouncer
  │ 3. returns 'S'
  │ 4. performs TLS handshake with wildcard cert
  │ 5. reads StartupMessage
  │ 6. routes by dbname
  ▼
PostgreSQL backend (ssl=off)
```

## What gets created

- Namespace: `demo-db-standard`
- Optional `ClusterIssuer` and Cloudflare token secret examples
- cert-manager `Certificate` for `*.db.infrasnow.com`
- Dedicated Gateway `postgres-std-gateway` with a TCP listener on `5432`
- `BackendTrafficPolicy` for TCP backend behavior
- Two PostgreSQL 17 StatefulSets with `ssl=off`
- PgBouncer Deployment and Service
- One `TCPRoute` from the Gateway listener to PgBouncer

## Routing model

Routing happens in PgBouncer by database name:

| Client dbname | Backend |
|---|---|
| `appdb_1` | `demo-postgres-1` |
| `appdb_2` | `demo-postgres-2` |

The hostname is still useful for TLS certificate validation, but it is **not** used for routing in this design.

## Why this works without `sslnegotiation=direct`

Normal PostgreSQL clients do this:

1. open a TCP connection
2. send `SSLRequest`
3. wait for the server to reply with `S`
4. start the TLS handshake

PgBouncer understands that flow. A Gateway TLS listener does not.

Because Envoy Gateway is only proxying raw TCP here, the PostgreSQL handshake remains intact and stock clients can use:

- `sslmode=verify-full`
- no `sslnegotiation=direct`

## Tradeoff

This design restores client compatibility, but you lose hostname-based routing at the Gateway layer.

If you need `demo-pg-1.db.infrasnow.com` and `demo-pg-2.db.infrasnow.com` to select different tenants without changing `dbname`, you need one of these:

- a dedicated PgBouncer or proxy service per tenant
- a custom PostgreSQL-aware proxy that routes by SNI or StartupMessage
- a different public entrypoint model than shared Gateway TLS passthrough

## Apply

```sh
kubectl kustomize gateway/databases/demo-postgres-gateway/tls-termination | kubectl apply -f -
```

## Verify

### Certificate

```sh
kubectl get certificate -n demo-db-standard pg-wildcard-cert
kubectl get secret -n demo-db-standard pgbouncer-public-tls
```

Expected: `Ready=True`

### Gateway

```sh
kubectl get gateway -n default postgres-std-gateway
```

Expected: `Programmed=True`

### TCPRoute

```sh
kubectl get tcproute -n demo-db-standard
kubectl describe tcproute -n demo-db-standard postgres-standard-clients
```

Expected: `Accepted=True`

### PgBouncer

```sh
kubectl get pods -n demo-db-standard -l app.kubernetes.io/name=pgbouncer
kubectl get svc -n demo-db-standard pgbouncer
```

### TLS handshake

```sh
openssl s_client \
  -connect demo-pg-1.db.infrasnow.com:5432 \
  -servername demo-pg-1.db.infrasnow.com -starttls postgres
```

Expected: a valid certificate for `*.db.infrasnow.com`

## Connect

### PostgreSQL instance 1

```sh
PGPASSWORD=demo-password psql \
  "host=demo-pg-1.db.infrasnow.com port=5432 user=demo dbname=appdb_1 sslmode=verify-full sslrootcert=system"
```

### PostgreSQL instance 2

```sh
PGPASSWORD=demo-password psql \
  "host=demo-pg-2.db.infrasnow.com port=5432 user=demo dbname=appdb_2 sslmode=verify-full sslrootcert=system"
```

### Verify backend selection

```sh
PGPASSWORD=demo-password psql \
  "host=demo-pg-1.db.infrasnow.com port=5432 user=demo dbname=appdb_1 sslmode=require" \
  -c "select current_database(), inet_server_addr();"

PGPASSWORD=demo-password psql \
  "host=demo-pg-2.db.infrasnow.com port=5432 user=demo dbname=appdb_2 sslmode=require" \
  -c "select current_database(), inet_server_addr();"
```

## Operational notes

- PgBouncer is the public TLS endpoint, so wildcard certificate rotation must be reflected there.
- PostgreSQL is configured with `ssl=off` in this demo. Add internal TLS later if required by your threat model.
- PgBouncer uses `auth_type = md5` here for a simple demo path. For production, prefer stronger auth management and move backend credentials out of static inline config.
- `pool_mode = transaction` is usually the safest default, but applications that rely on session state may need `session`.
