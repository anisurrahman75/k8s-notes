# Port-Based PostgreSQL Routing Architecture

## Overview

This architecture exposes PostgreSQL DBaaS instances using **dedicated TCP ports per tenant** via Envoy Gateway and Gateway API `TCPRoute`. Each tenant gets a unique external port on the load balancer.

## Traffic Flow

```
Client (psql)
  |
  | host=db.infrasnow.com port=30001 sslmode=require
  v
Cloud LoadBalancer (34.93.192.139:30001)
  |
  v
Envoy Gateway listener :30001 (L4 TCP proxy)
  |
  v
TCPRoute (tenant-a-postgres-route)
  |
  v
PgBouncer Service (pgbouncer-tenant-a:5432)
  |
  v
PostgreSQL StatefulSet (postgres-tenant-a:5432)
```

## Port Allocation

| Tenant   | External Port | Gateway Listener      | TCPRoute                    | PgBouncer Service      |
|----------|---------------|-----------------------|-----------------------------|------------------------|
| tenant-a | 30001         | tenant-a-postgres     | tenant-a-postgres-route     | pgbouncer-tenant-a     |
| tenant-b | 30002         | tenant-b-postgres     | tenant-b-postgres-route     | pgbouncer-tenant-b     |

## Connection Examples

```bash
# Tenant A
psql "host=db.infrasnow.com port=30001 user=tenant-a dbname=appdb sslmode=require"

# Tenant B
psql "host=db.infrasnow.com port=30002 user=tenant-b dbname=appdb sslmode=require"
```

## DNS Setup

Single DNS record pointing to the LoadBalancer IP:

```
db.infrasnow.com  A  34.93.192.139
```

Clients differentiate only by port number.

## Why TCPRoute is Simpler Operationally

1. **No TLS certificate management at Gateway** - Envoy does not terminate TLS, so no wildcard certs needed at the gateway layer
2. **No SNI matching complexity** - Routing is purely port-based, no hostname parsing
3. **Simple debugging** - `telnet db.infrasnow.com 30001` directly tests connectivity
4. **Predictable routing** - Port-to-service mapping is explicit and static
5. **No DNS coordination** - Single DNS record serves all tenants
6. **Fewer moving parts** - No TLSRoute, no hostname negotiation, no SNI extraction

## Why TCPRoute Scales Worse Than TLSRoute

1. **Port exhaustion** - LoadBalancer services require a NodePort or cloud LB port per listener. Cloud providers have limits (e.g., GCP: ~100 ports per LB)
2. **Listener proliferation** - Each tenant adds a new listener to the Gateway, increasing Envoy config size
3. **Operational overhead** - Port allocation must be tracked and managed (conflicts, documentation)
4. **Cloud provider limits** - Most cloud LBs have hard limits on port count or forwarding rules
5. **No multiplexing** - TLSRoute can serve thousands of hostnames on a single port (443). TCPRoute needs one port per tenant
6. **Firewall rules** - Each new port may require security group/firewall updates

## When TCPRoute is the Correct Choice

1. **Small tenant count** (< 20 tenants) where port exhaustion is not a concern
2. **Legacy clients** that cannot use SNI or hostname-based routing
3. **Compliance requirements** that mandate port-level isolation
4. **Simple environments** where operational complexity must be minimized
5. **Internal/private networks** where cloud LB limits do not apply
6. **Proof of concept** or development environments

## Production Security Practices

1. **TLS end-to-end** - Enable SSL in PostgreSQL. PgBouncer terminates client TLS, re-encrypts to backend
2. **NetworkPolicies** - Default deny, allow only Envoy Gateway namespace ingress, restrict cross-tenant access
3. **Secrets management** - Use External Secrets Operator or Sealed Secrets for production credentials
4. **Pod security** - Run as non-root, read-only filesystem, drop all capabilities
5. **Resource limits** - ResourceQuota and LimitRange prevent resource exhaustion
6. **Audit logging** - Enable PostgreSQL `log_connections` and `log_disconnections`

## Envoy Gateway Scaling

```yaml
# EnvoyGateway deployment resource tuning (in envoy-gateway-system)
resources:
  requests:
    cpu: 500m
    memory: 512Mi
  limits:
    cpu: "2"
    memory: 2Gi

# Horizontal scaling for high connection counts
replicas: 2
```

## HA Recommendations

1. **PgBouncer** - 2 replicas per tenant with `transaction` pool mode
2. **PostgreSQL** - Single primary with streaming replication (use CloudNativePG operator for production)
3. **WAL archiving** - Archive to S3/GCS for point-in-time recovery
4. **Backups** - Daily full + continuous WAL archiving via pgBackRest or Barman

## Monitoring

1. **Envoy metrics** - `/stats` endpoint, Prometheus scrape on port 19001
2. **PostgreSQL metrics** - `pg_stat_statements`, `pg_stat_activity`
3. **PgBouncer metrics** - `SHOW STATS`, `SHOW POOLS` via admin console

## Operational Limitations

1. **Port exhaustion** - Hard limit on number of tenants (cloud LB dependent)
2. **Port tracking** - Must maintain allocation registry to prevent conflicts
3. **Scaling friction** - Adding a tenant requires Gateway update + port allocation
4. **Automation complexity** - Operator needed for automated provisioning
5. **LB listener limits** - Cloud providers limit listeners per LB (typically 50-100)

## Recommended Operator Architecture

```yaml
apiVersion: dbaas.infrasnow.com/v1alpha1
kind: PostgresInstance
metadata:
  name: tenant-c
spec:
  port: 30003           # Auto-allocated by operator
  replicas: 1
  storage: 10Gi
  pgbouncer:
    replicas: 2
    poolMode: transaction
    maxClientConn: 1000
  backup:
    schedule: "0 2 * * *"
    retention: 7d
```

### Operator Reconciliation Flow

1. Watch `PostgresInstance` CR
2. Allocate port from available pool (30001-30999)
3. Generate Gateway listener entry
4. Generate TCPRoute
5. Generate PgBouncer Deployment + Service
6. Generate PostgreSQL StatefulSet + Service
7. Generate NetworkPolicies
8. Generate Secrets (or reference external)
9. Update status with connection string
10. Monitor health and report conditions

## Manifest Files

| File | Description |
|------|-------------|
| `00-namespace.yaml` | Namespace with route-allowed label |
| `01-gateway.yaml` | Gateway with TCP listeners per tenant |
| `02-tcproutes.yaml` | TCPRoute per tenant |
| `03-pgbouncer.yaml` | PgBouncer Deployment + Service per tenant |
| `04-postgresql.yaml` | PostgreSQL StatefulSet + Service per tenant |
| `05-networkpolicies.yaml` | Default deny + allow envoy + restrict cross-tenant |
| `06-resourcequota-limitrange.yaml` | Resource quotas and limits |

## Deployment

```bash
export KUBECONFIG=/home/anisur/KUBECONFIG/obaydullah

# Apply all manifests
kubectl apply -k .

# Verify
kubectl get gateway -n port-routing
kubectl get tcproute -n port-routing
kubectl get pods -n port-routing
```
