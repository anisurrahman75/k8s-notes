# ISSUE-001 — No-proxy PostgreSQL leaves a dead pgbouncer Service + misleading status

**Status:** Known limitation / upstream bug
**Severity:** Low (cosmetic + footgun for connections), Workaround available
**Components:** `openeverest-operator` (custom build) × `percona-postgresql-operator` v2.8.2
**Discovered:** 2026-06-24
**Related:** `dev.md` (build/deploy), `HANDOFF.md`

---

## Summary

Requesting a PostgreSQL `DatabaseCluster` with **no proxy** (`spec.proxy.replicas: 0`) gives
you **zero pgbouncer pods** (the actual goal), but the cluster still carries:

1. A live **`…-pgbouncer` Service with `<none>` endpoints** (no backing pod → connections to it hang/fail), and
2. A **`pgbouncer` ConfigMap/Secret**, and
3. A **`DatabaseCluster.status` that reports the hostname as `…-pgbouncer.<ns>.svc`** — a misleading
   endpoint, since nothing serves it.

So "no proxy" is only *mostly* true: no pgbouncer *resources* run, but the proxy's Service and
status field remain. Clients must connect to the **`-primary`** service, not the hostname in status.

## Why it happens (root cause)

Two layers are involved:

- **Everest operator (`openeverest-operator`)** — `internal/controller/everest/providers/pg/applier.go`
  `Proxy()` always populates `pg.Spec.Proxy.PGBouncer` and copies the requested replica count through.
  With `replicas: 0` it sets `PerconaPGCluster.spec.proxy.pgBouncer.replicas = 0`. The Everest status
  logic reports the proxy hostname regardless of replica count.
- **Percona PG operator (PGO) v2.8.2** — treats `pgBouncer.replicas: 0` as "configured but scaled to 0":
  it keeps the pgbouncer **Service**, **ConfigMap**, **Secret**, and a **Deployment at 0/0**, creating no pod.

The *clean* alternative — setting `PerconaPGCluster.spec.proxy = nil` (which the crunchy layer handles as
"PGBouncer disabled", removing Service/ConfigMap/Deployment entirely) — **cannot be used**, because:

> **PGO v2.8.2 crashes (CrashLoopBackOff) on `spec.proxy == nil`.** A cache field-index function
> registered in `init()` dereferences the proxy without a nil check. The moment a `PerconaPGCluster`
> with a nil proxy is cached, the operator panics and restarts in a loop.

Evidence (from PGO v2.9.0 source, structurally identical to 2.8.2):
- `pkg/apis/pgv2.percona.com/v2/perconapgcluster_types.go` — defaulter re-creates `pgBouncer` when nil
  (lines ~246-256), implying nil was never an expected runtime state for the Percona layer.
- Crash trace: `init.func2` → `cache.indexByField` → `storeIndex.updateSingleIndex` (nil pointer deref).

## Reproduction

Prereq: OpenEverest minimal install (PostgreSQL only) on a cluster; the custom everest-operator image
that allows `proxy.replicas: 0` (`docker.io/anisurrahman75/openeverest-operator:1.13.0-noproxy-v3`).

```bash
export KUBECONFIG=/home/anisur/KUBECONFIG/obaydullah

# 1) Create a PG cluster with no proxy
kubectl apply -f - <<'EOF'
apiVersion: everest.percona.com/v1alpha1
kind: DatabaseCluster
metadata: { name: pg-noproxy, namespace: everest }
spec:
  engine: { type: postgresql, version: "16.11", replicas: 1,
            storage: { size: 1Gi }, resources: { cpu: "500m", memory: 512M } }
  proxy: { type: pgbouncer, replicas: 0 }
EOF

# 2) Observe the leftover pgbouncer Service with NO endpoints, and primary WITH an endpoint:
kubectl get endpoints -n everest pg-noproxy-pgbouncer   # -> <none>
kubectl get endpoints -n everest pg-noproxy-primary     # -> <ip>:5432

# 3) Status hostname misleadingly points at the dead pgbouncer svc:
kubectl get databasecluster pg-noproxy -n everest -o jsonpath='{.status.host}{"\n"}'   # …-pgbouncer…

# 4) Connecting to the status hostname FAILS; connecting to -primary WORKS:
#    (see Connection section below)
```

### Reproducing the nil-proxy crash (do NOT run on a cluster you need)

```bash
# Patch the underlying CR to null the proxy — PGO will then CrashLoop.
kubectl patch perconapgcluster pg-noproxy -n everest --type=merge -p '{"spec":{"proxy":null}}'
kubectl get pods -n everest | grep postgresql-operator   # -> CrashLoopBackOff
# Recovery: restore a non-nil proxy, then delete/restart the operator pod.
kubectl patch perconapgcluster pg-noproxy -n everest --type=merge \
  -p '{"spec":{"proxy":{"pgBouncer":{"replicas":0}}}}'
kubectl delete pod -n everest -l app.kubernetes.io/name=percona-postgresql-operator
```

## Impact

- **Resource cost:** none — no pgbouncer pod runs (the goal is met).
- **Footgun:** any client/app that reads `DatabaseCluster.status.host` and connects to it will fail
  silently (the `…-pgbouncer` Service has no endpoints). Must use `…-primary.<ns>.svc:5432`.
- **Cosmetic:** an empty pgbouncer Service/ConfigMap/Secret linger in the namespace.

## Workaround (current)

Keep `proxy.replicas: 0`; **connect to the `-primary` service**, ignore the pgbouncer hostname in status.

```bash
# Inside the cluster / a pod:
psql "host=pg-noproxy-primary.everest.svc port=5432 user=postgres dbname=postgres"
# Credentials: kubectl get secret everest-secrets-pg-noproxy -n everest \
#   -o go-template='{{range $k,$v := .data}}{{$k}}={{$v|base64decode}}{{"\n"}}{{end}}'

# Or exec into the instance pod and connect to localhost:
kubectl exec -i -n everest pg-noproxy-instance1-<id>-0 -c database -- \
  env PGPASSWORD="$(kubectl get secret everest-secrets-pg-noproxy -n everest \
    -o jsonpath='{.data.password}' | base64 -d)" \
  psql -h 127.0.0.1 -U postgres -d postgres
```

## Possible fixes (not implemented)

1. **Upstream PGO fix (proper):** guard the nil-proxy deref in the PGO cache indexer
   (`pkg/apis/pgv2.percona.com/v2` index funcs) and the defaulter, rebuild PGO, *then* set
   `proxy=nil` from the Everest applier. Removes Service/ConfigMap/status cleanly. Invasive — touches
   a vendored dependency.
2. **Everest status fix (partial):** when `proxy.replicas == 0`, have `openeverest-operator` report the
   `-primary` host in status (and/or clear the proxy block from status). Low-risk, improves UX, but
   the empty pgbouncer Service from PGO would still exist.
3. **Upgrade PGO:** if a newer PGO release fixed the nil-proxy crash, switch to `proxy=nil` and drop the
   `Minimum:=0` workaround entirely. Verify nil-proxy handling before relying on it.
4. **Accept:** document and move on — `replicas: 0` meets the resource goal.

## Verification performed (2026-06-24)

Connected directly to `pg-noproxy-primary` (no pgbouncer) and ran a create/insert/select round-trip:

```
PostgreSQL 16.11 - Percona Distribution
CREATE TABLE notes (id serial PRIMARY KEY, msg text, created_at timestamptz default now());
INSERT 0 3
 id | msg                                         | created_at
  1 | hello from the no-proxy pg cluster          | 16:50:16
  2 | openeverest works end to end                | 16:50:16
  3 | connected directly to primary, no pgbouncer | 16:50:16
(3 rows)
```

PG operator remained healthy throughout (no crash). The `notes` table is intentionally left in place
as a working proof.
