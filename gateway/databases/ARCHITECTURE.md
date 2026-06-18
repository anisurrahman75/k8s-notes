# Multi-Tenant PostgreSQL DBaaS Architecture on Kubernetes

This design is based on the current manifests in this directory:

- `gateway-class.yaml` defines an Envoy Gateway `GatewayClass` named `eg`.
- `custom-envoy.yaml` configures Envoy Gateway with a `LoadBalancer` service, `externalTrafficPolicy: Local`, and `mergeGateways: true`.
- `gateway.yaml` currently exposes HTTP/HTTPS listeners for `*.infrasnow.com` with TLS termination.

The existing Gateway is appropriate for web traffic, but PostgreSQL is not HTTP. External PostgreSQL access should use Gateway API `TLSRoute` with TLS passthrough when SNI-based routing is required. `TCPRoute` is only suitable when each database gets its own listener, port, or load balancer address because plain TCP has no hostname/SNI routing signal.

## Recommended Architecture

Use an operator-driven model where users create a high-level PostgreSQL custom resource. The operator provisions a PostgreSQL cluster, service, credentials, backup configuration, monitoring resources, and optional external exposure through Gateway API.

Recommended components:

- `PostgresInstance` CRD: user-facing API for database size, version, storage, HA, backups, and external exposure.
- PostgreSQL operator: reconciles `PostgresInstance` into database resources. Prefer proven operators such as CloudNativePG, Crunchy Postgres Operator, or Zalando Postgres Operator instead of building database lifecycle logic from scratch.
- Envoy Gateway: shared external data-plane for exposed PostgreSQL instances.
- Gateway API `TLSRoute`: SNI-based routing for PostgreSQL TLS passthrough.
- Per-instance Kubernetes `Service`: stable backend target for each PostgreSQL primary or proxy endpoint.
- DNS wildcard: maps database hostnames to the Envoy Gateway load balancer.
- NetworkPolicies: isolate tenants and allow only required traffic paths.

High-level flow:

```text
User
  |
  | psql "host=pg-a.db.infrasnow.com port=5432 sslmode=require"
  v
Wildcard DNS: *.db.infrasnow.com
  |
  v
Cloud Load Balancer
  |
  v
Envoy Gateway listener :5432
  |
  | TLS passthrough, route by SNI pg-a.db.infrasnow.com
  v
TLSRoute
  |
  v
tenant namespace Service
  |
  v
PostgreSQL primary endpoint / pooler / HA proxy
```

## PostgreSQL Deployment Model

For production, do not expose individual PostgreSQL pods directly. Expose a stable service managed by the database operator.

Recommended per instance:

- One namespace per tenant for strong isolation, or one namespace per environment plus strict RBAC and NetworkPolicies.
- Stateful PostgreSQL cluster with persistent volumes.
- HA mode with one primary and at least one replica for production tiers.
- A stable primary service such as `pg-a-rw` for writes.
- Optional read-only service such as `pg-a-ro` for replicas.
- Optional PgBouncer service in front of PostgreSQL for connection pooling.
- Backup object storage target using S3-compatible storage.

Preferred external backend target:

```text
TLSRoute -> PgBouncer Service -> PostgreSQL primary service
```

If PgBouncer is not used:

```text
TLSRoute -> PostgreSQL primary Service
```

PgBouncer is strongly recommended for multi-tenant DBaaS because PostgreSQL connections are expensive and external clients can create bursty connection load.

## Gateway API Routing

### Use `TLSRoute` for Shared Port SNI Routing

Use `TLSRoute` when many PostgreSQL instances share a single external load balancer and port `5432`.

Requirements:

- PostgreSQL must use TLS.
- Clients must start TLS immediately and send SNI. For `psql`/libpq, use PostgreSQL 17+ direct SSL negotiation with `sslnegotiation=direct`.
- Envoy must use TLS passthrough.
- Each database gets a hostname such as `pg-a.db.infrasnow.com`.

This is the recommended production model.

### Use `TCPRoute` Only for Dedicated Ports or Addresses

Use `TCPRoute` when routing by hostname is not needed or not possible.

Examples:

- `db-gateway.infrasnow.com:30001` routes to tenant A.
- `db-gateway.infrasnow.com:30002` routes to tenant B.
- Dedicated load balancer IP per tenant.

This is operationally worse at scale because it consumes ports or load balancer resources and is harder to automate cleanly.

For a minimal demo with a plain PostgreSQL StatefulSet, `TLSRoute` works when the client uses direct SSL negotiation. Standard PostgreSQL negotiation first sends a PostgreSQL SSL request packet and only starts TLS after the server responds, so a generic TLS/SNI listener may not see a TLS ClientHello at the start of the connection. The `demo-postgres-gateway` manifests use PostgreSQL 17 and require `sslnegotiation=direct` for this reason.

## TLS Passthrough vs Termination

Recommended: TLS passthrough at Envoy, TLS termination at PostgreSQL or PgBouncer.

Reasons:

- PostgreSQL is not HTTP; terminating TLS at the Gateway does not make it an application-aware PostgreSQL proxy.
- End-to-end database TLS is easier to reason about for compliance.
- SNI can still be inspected by Envoy without decrypting traffic.
- Tenant certificates and client authentication can be enforced at the database or pooler layer.

Use TLS termination at Envoy only if you introduce a proper PostgreSQL-aware proxy behind Envoy and have a clear reason to centralize certificate handling. For normal DBaaS, passthrough is the safer default.

## DNS Strategy

Use a dedicated database subdomain:

```text
*.db.infrasnow.com -> Envoy Gateway LoadBalancer address
```

Example hostnames:

```text
pg-a.db.infrasnow.com
pg-b.db.infrasnow.com
customer-123-prod.db.infrasnow.com
```

Avoid mixing HTTP application traffic and PostgreSQL traffic under the same listener design. Keep web traffic on `80/443` and database traffic on `5432`.

Recommended DNS automation:

- Use ExternalDNS to publish wildcard or per-instance records.
- Prefer wildcard DNS for simpler scaling.
- If per-instance DNS is required, have the DBaaS operator create `DNSEndpoint` resources or integrate with your DNS provider.

## Multi-Tenant Isolation

Recommended isolation model:

- Namespace per tenant for production tenants.
- Separate service accounts per tenant and per operator component.
- RBAC prevents tenants from reading other tenants' Secrets, Services, Routes, PVCs, or backups.
- NetworkPolicies deny traffic by default.
- ResourceQuota and LimitRange per namespace.
- StorageClass policies for allowed volume types.
- Pod Security Admission set to `restricted` where compatible.
- Separate backup prefixes/buckets or IAM-scoped paths per tenant.

For stronger isolation:

- Dedicated node pools per tenant tier.
- Taints/tolerations for premium or regulated tenants.
- Separate Gateway or load balancer per trust boundary.
- Separate clusters for hard isolation requirements.

## Current Manifest Assessment

The current `gateway.yaml`:

```yaml
listeners:
  - name: http
    port: 80
    protocol: HTTP
  - name: https
    port: 443
    protocol: HTTPS
    tls:
      mode: Terminate
```

This does not expose PostgreSQL. Add a separate TLS passthrough listener on port `5432`.

The current `custom-envoy.yaml`:

```yaml
externalTrafficPolicy: Local
type: LoadBalancer
mergeGateways: true
```

This is a reasonable starting point. `externalTrafficPolicy: Local` preserves client source IP but requires Envoy pods to be present on nodes receiving load balancer traffic. In production, run multiple Envoy replicas with topology spread or node placement that matches your cloud load balancer behavior.

## Example Gateway Manifests

Keep HTTP/HTTPS for web traffic, and add a dedicated PostgreSQL TLS passthrough listener.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: gateway
  namespace: default
spec:
  gatewayClassName: eg
  listeners:
    - name: http
      hostname: "*.infrasnow.com"
      port: 80
      protocol: HTTP
      allowedRoutes:
        namespaces:
          from: All
    - name: https
      hostname: "*.infrasnow.com"
      port: 443
      protocol: HTTPS
      tls:
        mode: Terminate
        certificateRefs:
          - group: ""
            kind: Secret
            name: infrasnow-cert
      allowedRoutes:
        namespaces:
          from: All
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

Example tenant namespace:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: tenant-a
  labels:
    dbaas.infrasnow.com/routes-allowed: "true"
```

Example `TLSRoute`:

```yaml
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: TLSRoute
metadata:
  name: pg-a-external
  namespace: tenant-a
spec:
  parentRefs:
    - name: gateway
      namespace: default
      sectionName: postgres-tls
  hostnames:
    - pg-a.db.infrasnow.com
  rules:
    - backendRefs:
        - name: pg-a-pgbouncer
          port: 5432
```

If not using PgBouncer, route to the operator-managed primary service:

```yaml
backendRefs:
  - name: pg-a-rw
    port: 5432
```

Check the installed Gateway API and Envoy Gateway versions before applying this exact manifest. In some installations, `TLSRoute` may require the experimental Gateway API CRDs.

## Example User-Facing CRD

```yaml
apiVersion: dbaas.infrasnow.com/v1alpha1
kind: PostgresInstance
metadata:
  name: pg-a
  namespace: tenant-a
spec:
  version: "16"
  storage:
    size: 100Gi
    className: fast-ssd
  compute:
    requests:
      cpu: "1"
      memory: 4Gi
    limits:
      cpu: "2"
      memory: 8Gi
  highAvailability:
    enabled: true
    replicas: 2
  pooling:
    enabled: true
    poolMode: transaction
    maxClientConnections: 500
  externalAccess:
    enabled: true
    hostname: pg-a.db.infrasnow.com
    gatewayRef:
      name: gateway
      namespace: default
      sectionName: postgres-tls
  backups:
    enabled: true
    schedule: "0 */6 * * *"
    retention: 30d
    objectStore:
      bucket: infrasnow-pg-backups
      prefix: tenant-a/pg-a
  monitoring:
    enabled: true
```

The DBaaS operator should reconcile this into:

- PostgreSQL operator cluster resource.
- Secret for generated credentials.
- Service for primary and replica endpoints.
- PgBouncer deployment/service if enabled.
- TLS certificate Secret for PostgreSQL/PgBouncer.
- `TLSRoute` if `externalAccess.enabled=true`.
- Backup schedule and restore metadata.
- ServiceMonitor/PodMonitor and alerts.

## Connection Flow

Provisioning flow:

```text
User creates PostgresInstance
  -> DBaaS operator validates quota, hostname, policy
  -> DBaaS operator creates PostgreSQL operator resource
  -> PostgreSQL operator creates StatefulSet, PVCs, Services, Secrets
  -> DBaaS operator creates PgBouncer if enabled
  -> DBaaS operator creates TLSRoute for external access
  -> Envoy Gateway programs Envoy listener/routes
  -> User receives hostname, port, CA bundle, credentials
```

Runtime flow:

```text
Client opens TLS connection to pg-a.db.infrasnow.com:5432
  -> DNS resolves to Envoy Gateway LoadBalancer
  -> Envoy receives TLS ClientHello with SNI pg-a.db.infrasnow.com
  -> TLSRoute matches hostname
  -> Envoy forwards encrypted TCP stream to pg-a-pgbouncer:5432
  -> PgBouncer/PostgreSQL terminates TLS
  -> PostgreSQL authentication and authorization happen normally
```

## Security Controls

Minimum production controls:

- Require TLS for all external and in-cluster PostgreSQL connections.
- Use per-instance certificates or wildcard database certificates.
- Prefer SCRAM-SHA-256 for password authentication.
- Consider client certificate authentication for high-security tenants.
- Store credentials in Kubernetes Secrets, ideally synced from an external secret manager.
- Rotate credentials and certificates automatically.
- Deny all namespace ingress by default.
- Allow ingress only from Envoy Gateway namespace to exposed database services.
- Allow operator access only to namespaces it manages.
- Do not allow tenant-created arbitrary `TLSRoute` resources unless policy validation is in place.

Example NetworkPolicy allowing Envoy Gateway to reach a tenant DB service:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-envoy-to-postgres
  namespace: tenant-a
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/instance: pg-a
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: envoy-gateway-system
      ports:
        - protocol: TCP
          port: 5432
```

Also add default deny policies per tenant namespace:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: tenant-a
spec:
  podSelector: {}
  policyTypes:
    - Ingress
```

Use an admission policy layer such as Kyverno, Gatekeeper, or ValidatingAdmissionPolicy to enforce:

- Hostnames must be under `*.db.infrasnow.com`.
- `TLSRoute.parentRefs` must point only to approved Gateway listeners.
- Tenants cannot reference Services in other namespaces.
- External access requires an approved plan or policy.

## HA and Scalability

PostgreSQL HA:

- Use synchronous or asynchronous replicas depending on RPO and latency requirements.
- Use PodDisruptionBudgets.
- Spread replicas across zones.
- Configure backups and WAL archiving.
- Test failover regularly.

Envoy Gateway HA:

- Run at least two Envoy replicas.
- Use topology spread constraints across nodes/zones.
- Monitor listener, route, upstream, and connection metrics.
- Size Envoy for long-lived TCP connections, not just request rate.
- Tune connection limits and idle timeouts carefully for PostgreSQL clients.

Scaling considerations:

- PostgreSQL does not scale writes horizontally in the same way stateless services do. Scale primarily by vertical sizing, read replicas, pooling, and sharding at the platform layer when required.
- PgBouncer should be enabled by default for small and medium plans.
- Limit maximum client connections per tenant.
- Enforce quotas for CPU, memory, storage, IOPS, backup retention, and external routes.

## Backup and Restore

Production backup requirements:

- Continuous WAL archiving to object storage.
- Scheduled base backups.
- Point-in-time recovery.
- Per-tenant retention policy.
- Backup encryption.
- Restore testing automation.
- Separate restore workflow that can create a new `PostgresInstance` from a backup or timestamp.

Example restore CRD:

```yaml
apiVersion: dbaas.infrasnow.com/v1alpha1
kind: PostgresRestore
metadata:
  name: pg-a-restore-2026-05-17
  namespace: tenant-a
spec:
  source:
    instanceName: pg-a
    recoveryTargetTime: "2026-05-17T00:00:00Z"
  target:
    instanceName: pg-a-restored
    externalAccess:
      enabled: false
```

## Monitoring and Observability

Collect:

- PostgreSQL metrics: connections, locks, replication lag, cache hit ratio, transaction rate, deadlocks, slow queries.
- PgBouncer metrics: pool saturation, wait time, server/client connections.
- Envoy metrics: downstream connections, upstream connection failures, TLS/SNI route matches, resets.
- Kubernetes metrics: pod restarts, PVC usage, CPU/memory, node pressure.
- Backup metrics: last successful backup, WAL archive lag, restore success/failure.

Recommended alerts:

- PostgreSQL primary down.
- Replication lag above threshold.
- Storage above 80 percent and 90 percent.
- Connection pool saturation.
- Backup failed or stale.
- Envoy no healthy upstream.
- TLSRoute not accepted or unresolved backend.

## Final Recommendation

Use `TLSRoute` with TLS passthrough on a dedicated Gateway listener at port `5432`, route by SNI using hostnames under `*.db.infrasnow.com`, and terminate TLS at PgBouncer or PostgreSQL. Keep the current HTTP/HTTPS Gateway listeners for web workloads, but do not use them for PostgreSQL.

Build the DBaaS API around a `PostgresInstance` CRD, but delegate PostgreSQL lifecycle to an established PostgreSQL operator. The custom DBaaS operator should focus on tenancy, policy, external routing, DNS, quotas, credentials, backup orchestration, and user-facing status.
