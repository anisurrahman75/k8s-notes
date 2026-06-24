# OpenEverest — Minimal Install (PostgreSQL)

Notes and manifests for running [Percona Everest / OpenEverest](https://docs.percona.com/everest/)
as a **minimal, PostgreSQL-only** deployment via Helm, plus customized `DatabaseCluster`
examples.

Everest is a cloud-native database platform: it installs database **operators** (PXC,
PSMDB, PostgreSQL) through **OLM** (Operator Lifecycle Manager) and lets you manage
database clusters declaratively (`DatabaseCluster` CRs) or via a web UI.

---

## Contents

```
openeverest/
├── README.md
└── manifests/
    ├── 01-pg-minimal.yaml              # single node, smallest footprint
    ├── 02-pg-ha.yaml                   # 3-node HA + 2 pgbouncer
    ├── 03-pg-exposed-loadbalancer.yaml # exposed via LoadBalancer
    ├── 04-pg-custom-config.yaml        # custom postgresql.conf + anti-affinity
    └── 05-pg-with-backup.yaml          # scheduled backups + PITR
```

---

## Prerequisites

- A Kubernetes cluster (tested on **k3s**, v1.34) with a default `StorageClass`.
- `helm` v3 and `kubectl`.
- Add the Percona Helm repo:
  ```bash
  helm repo add percona https://percona.github.io/percona-helm-charts/
  helm repo update percona
  ```

---

## Installation (minimal: PostgreSQL only)

```bash
helm upgrade -i everest-core percona/everest \
  --namespace everest-system --create-namespace \
  --set dbNamespace.pxc=false \
  --set dbNamespace.psmdb=false \
  --set monitoring.enabled=false \
  --set kube-state-metrics.enabled=false \
  --set createMonitoringResources=false \
  --timeout 20m --wait
```

### What each flag does

| Flag | Effect |
|------|--------|
| `dbNamespace.pxc=false` | Don't install the Percona XtraDB (MySQL) operator |
| `dbNamespace.psmdb=false` | Don't install the Percona Server for MongoDB operator |
| `dbNamespace.postgresql` *(default `true`)* | Keep the PostgreSQL operator — **left on** |
| `monitoring.enabled=false` | Skip the Victoria Metrics monitoring stack |
| `kube-state-metrics.enabled=false` | Skip kube-state-metrics |
| `createMonitoringResources=false` | Skip the `VM*Scrape` CRs targeting `everest-monitoring` |
| `--timeout 20m --wait` | OLM + operator install can exceed Helm's default 5 min |

> ⚠️ **Do NOT set `olm.install=false`.** OLM is **required** — it is what turns the
> operator `Subscription` into a running operator (`Subscription → InstallPlan → CSV`).
> Without it the post-install hook hangs on *"Waiting for InstallPlan…"* and the install
> fails with `timed out waiting for the condition`. Only disable OLM if a compatible OLM
> is already installed in the cluster.

### Namespaces created

| Namespace | Contents |
|-----------|----------|
| `everest-system` | `everest-server` (API + UI), `everest-operator` |
| `everest-olm` | OLM: `olm-operator`, `catalog-operator`, `packageserver`, catalog source |
| `everest` | DB operators (postgresql) + your `DatabaseCluster`s live here |

---

## Verify the install

```bash
helm status everest-core -n everest-system            # STATUS: deployed
kubectl get pods -n everest-system
kubectl get pods -n everest-olm
kubectl get databaseengines -n everest                # postgresql -> installed
```

Expected `DatabaseEngine`:

```
NAME                          TYPE         STATUS      OPERATOR VERSION
percona-postgresql-operator   postgresql   installed   2.8.2
```

List the recommended PostgreSQL versions you can use in `spec.engine.version`:

```bash
kubectl get databaseengine percona-postgresql-operator -n everest \
  -o jsonpath='{.status.availableVersions.engine}' | tr ',' '\n'
```

---

## Accessing the Everest UI

```bash
kubectl port-forward svc/everest 8080:8080 -n everest-system
# open http://localhost:8080
```

Get / reset the admin password (the stored value is only a hash):

```bash
everestctl accounts initial-admin-password -n everest-system
# or reset:
everestctl accounts set-password --username admin
```

> `everestctl` is Everest's CLI — install it from the
> [releases page](https://github.com/percona/everest/releases) if you don't have it.

---

## Deploying a database

Apply any manifest from `manifests/` (they target the `everest` namespace):

```bash
kubectl apply -f manifests/01-pg-minimal.yaml
kubectl get databasecluster -n everest -w
```

Ready output:

```
NAME         SIZE   READY   STATUS   HOSTNAME                           AGE
pg-minimal   2      2       ready    pg-minimal-pgbouncer.everest.svc   90s
```

### Connecting to a PostgreSQL cluster

Credentials live in the `everest-secrets-<name>` Secret in the `everest` namespace:

```bash
kubectl get secret everest-secrets-pg-minimal -n everest \
  -o go-template='{{range $k,$v := .data}}{{$k}}={{$v | base64decode}}{{"\n"}}{{end}}'
```

Keys include `user`, `password`, `host`, `port`, `pgbouncer-host`, `pgbouncer-port`.
In-cluster connection (via pgbouncer):

```bash
psql "host=pg-minimal-pgbouncer.everest.svc port=5432 user=<user> password=<password> dbname=postgres"
```
### Without Proxy
```bash
➤ kubectl run psql-client \
        --namespace everest \
        --image=postgres:latest \
        --rm -it \
        --restart=Never \
        -- /bin/bash
If you don't see a command prompt, try pressing enter.
root@psql-client:/# psql -h pg-noproxy-ha -p 5432
Password for user root: 
psql: error: connection to server at "pg-noproxy-ha" (10.43.94.124), port 5432 failed: FATAL:  password authentication failed for user "root"
connection to server at "pg-noproxy-ha" (10.43.94.124), port 5432 failed: FATAL:  no pg_hba.conf entry for host "10.42.0.238", user "root", database "root", no encryption
root@psql-client:/# PGPASSWORD='' \
psql -h pg-noproxy-ha -p 5432 -U postgres -d postgres
psql (18.4 (Debian 18.4-1.pgdg13+1), server 16.11 - Percona Distribution)
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, compression: off, ALPN: none)
Type "help" for help.

postgres=# 

```

---

## Manifest reference

| File | Engine replicas | Proxy | Storage | Highlights |
|------|-----------------|-------|---------|------------|
| `01-pg-minimal.yaml` | 1 | pgbouncer ×1 | 1Gi | smallest footprint |
| `02-pg-ha.yaml` | 3 | pgbouncer ×2 | 10Gi | streaming-replication HA |
| `03-pg-exposed-loadbalancer.yaml` | 1 | pgbouncer ×1 | 2Gi | `proxy.expose` + IP allow-list |
| `04-pg-custom-config.yaml` | 3 | pgbouncer ×2 | 5Gi | custom `postgresql.conf` / pgbouncer config + anti-affinity |
| `05-pg-with-backup.yaml` | 3 | pgbouncer ×2 | 10Gi | scheduled backups + PITR (needs a `BackupStorage`) |

### Key `DatabaseCluster` spec fields

- `spec.engine.type` — `postgresql` \| `pxc` \| `psmdb` (operator must be installed).
- `spec.engine.version` — must be an *available* version for the engine.
- `spec.engine.replicas` — number of DB instances (1 = no HA).
- `spec.engine.resources.{cpu,memory}` / `spec.engine.storage.{size,class}`.
- `spec.engine.config` — raw engine config appended to `postgresql.conf`.
- `spec.proxy.type` — `pgbouncer` (PG), `haproxy`/`proxysql` (PXC), `mongos` (PSMDB).
- `spec.proxy.expose.type` — `internal` (ClusterIP) or `LoadBalancer` (external).
- `spec.backup` — `schedules` (cron) + `pitr`; both reference a `BackupStorage`.
- `spec.podSchedulingPolicyName` — references a `PodSchedulingPolicy` CR (the chart ships
  `everest-default-postgresql`, `everest-default-mysql`, `everest-default-mongodb`).

> Adding MySQL/MongoDB later: re-run the Helm install with `dbNamespace.pxc=true` /
> `dbNamespace.psmdb=true`. Those operators are also delivered via OLM.

---

## Troubleshooting

**Install hangs / `failed post-install: timed out waiting for the condition`**
The `everest-operators-installer` job is waiting for an OLM `InstallPlan`. Check:
```bash
kubectl logs -n everest job/everest-operators-installer
kubectl get pods -n everest-olm                       # OLM must be running
kubectl get subscriptions,installplans,csv -n everest
```
If `everest-olm` is empty, OLM was not installed — you set `olm.install=false`. Remove
that flag and reinstall.

**`namespaces "everest-monitoring" not found`**
You disabled `monitoring.enabled` but not `createMonitoringResources`. Add
`--set createMonitoringResources=false`.

**Reinstall hangs deleting `PodSchedulingPolicy` (stuck `Terminating`)**
These cluster-scoped CRs have `helm.sh/resource-policy: keep` + a
`everest.percona.com/readonly-protection` finalizer, so a prior `helm uninstall` leaves
them and the next install's hook blocks forever trying to delete them. Clear the finalizer:
```bash
for p in everest-default-mysql everest-default-postgresql everest-default-mongodb; do
  kubectl patch podschedulingpolicies.everest.percona.com "$p" \
    --type=merge -p '{"metadata":{"finalizers":[]}}'
done
```

**Clean uninstall**
```bash
kubectl delete databasecluster --all -n everest        # delete DBs first
helm uninstall everest-core -n everest-system
# then clear leftovers if reinstalling:
kubectl delete ns everest everest-olm --ignore-not-found
kubectl get podschedulingpolicies.everest.percona.com  # remove finalizers if stuck (see above)
```

---

## References

- Everest docs: https://docs.percona.com/everest/
- Helm chart: https://github.com/percona/percona-helm-charts/tree/main/charts/everest
- `DatabaseCluster` API: `kubectl explain databasecluster.spec --recursive`
