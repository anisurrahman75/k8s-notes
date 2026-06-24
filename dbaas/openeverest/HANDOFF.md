# HANDOFF — OpenEverest "PostgreSQL without proxy" change

> ✅ **STATUS: COMPLETE & VERIFIED.** The `v3` image is deployed and the test passed:
> a `DatabaseCluster` with `proxy.replicas: 0` reaches `ready` with the pgbouncer
> Deployment at **0/0 (no pods)** and the PG operator stays healthy (no crash).
> The notes below are retained as a record of the work and how to reproduce/revert.

Context dump so another model/session can finish or reproduce. The **code change is done
and verified**; the corrected operator image (`v3`) is deployed.

## Environment
- **KUBECONFIG**: `/home/anisur/KUBECONFIG/obaydullah` (remote k3s on GCP, `34.93.192.139`).
  Always `export KUBECONFIG=/home/anisur/KUBECONFIG/obaydullah` before kubectl.
- Cluster is **remote** — cannot import images to node containerd. Must use a registry.
- **Docker Hub** is logged in as `anisurrahman75`. Push there.
- Operator source: `~/go/src/openeverest/openeverest-operator` (module `everest-operator`, branch `main`, NOT a git repo at parent).
- Notes/docs repo: `~/go/src/github.com/anisurrahman75/k8s-notes/dbaas/openeverest/`
  (contains `README.md`, `dev.md`, `manifests/`, this file).
- Everest installed (helm release `everest-core`, ns `everest-system`); PG-only minimal install.
  DB namespace is `everest`. A healthy `sample-pg` DatabaseCluster (with pgbouncer) runs there.

## Goal
Let an Everest PostgreSQL `DatabaseCluster` run with **zero pgbouncer pods** via
`spec.proxy.replicas: 0` (for resource-limited clusters).

## What the change is (FINAL, correct approach)
Only **one** source edit is required, plus one local-source fix:

1. **`api/everest/v1alpha1/databasecluster_types.go`** (~line 287): the `Proxy.Replicas`
   marker was changed `+kubebuilder:validation:Minimum:=1` → `Minimum:=0`. (DONE)
   - The applier (`internal/controller/everest/providers/pg/applier.go` `Proxy()`) already
     copies the requested replicas through to `PerconaPGCluster.spec.proxy.pgBouncer.replicas`,
     so `0` flows through → PGBouncer Deployment scales to 0 pods. **No applier change needed.**
   - We tried setting `pg.Spec.Proxy = nil` in the applier but **REVERTED it** — see GOTCHA #1.

2. **`cmd/main.go`** (~line 364): the local checkout had
   `SetupDatabaseClusterWebhookWithManager(mgr)` **commented out**. We **uncommented it**
   (DONE). Without it the binary 404s the deployed `mdatabasecluster`/`vdatabasecluster`
   webhooks → all DatabaseCluster ops fail. Keep it enabled.

`make manifests generate`, `go build ./...`, `go vet ./...` all pass. The regenerated CRD
(`config/crd/bases/everest.percona.com_databaseclusters.yaml`) has `minimum: 0` for proxy
replicas and was **already applied to the cluster** (server-side).

## GOTCHAS (do not repeat)
1. **PG operator v2.8.2 crashes on `PerconaPGCluster.spec.proxy == nil`.** A cache index
   function dereferences proxy without a nil check (CrashLoopBackOff). So DO NOT null the
   proxy. Use `replicas: 0` (proxy/pgBouncer stay non-nil; Deployment scales to 0). Result:
   pgbouncer Deployment exists at 0/0, Service/ConfigMap exist, but no pods (no resource use).
   Connect directly to `…-primary.everest.svc:5432`.
2. **`make docker-build` is very slow** (cold `go mod download` in-container + `go build -a`).
   Use the **fast host-build** path instead (see `dev.md` §2): host `go build` the 3 binaries
   into `bin/img/`, then `docker build -f bin/img/Dockerfile.fast`. `bin/img/` and
   `Dockerfile.fast` already exist with the v3 binaries.
3. Use a **new image tag each build** (node `imagePullPolicy: IfNotPresent` caches tags).

## Current deploy state
- Image tags pushed/pushing on Docker Hub: `…/openeverest-operator:1.13.0-noproxy` (v1, broken
  webhook), `…-noproxy-v2` (webhook fixed, but applier still had the bad proxy=nil), and
  **`…-noproxy-v3`** (FINAL: webhook enabled + applier reverted). **v3 push was still
  uploading** at handoff (slow upstream link, ~100MB manager layer). Tag stored in
  `/tmp/everest-op-hub-tag.txt`.
- The cluster's `everest-operator` Deployment currently runs **v2** image.
- PG operator (`percona-postgresql-operator` in ns `everest`) is healthy again (we deleted the
  bad nil-proxy CR and restarted it).

## REMAINING STEPS (do these to finish)
```bash
export KUBECONFIG=/home/anisur/KUBECONFIG/obaydullah
HUB3=$(cat /tmp/everest-op-hub-tag.txt)   # docker.io/anisurrahman75/openeverest-operator:1.13.0-noproxy-v3

# 1. Confirm v3 finished pushing:
docker manifest inspect "$HUB3" >/dev/null 2>&1 && echo PRESENT || echo "still pushing — wait"
#    (if still pushing: `pgrep -f '^docker push'`; just wait, do not rebuild)

# 2. Deploy v3 (update manager + crs-migration init container):
kubectl set image deploy/everest-operator -n everest-system manager="$HUB3" crs-migration="$HUB3"
kubectl rollout status deploy/everest-operator -n everest-system
kubectl get pod -n everest-system -l app=everest-operator -o jsonpath='{.items[0].spec.containers[0].image}{"\n"}'

# 3. Verify operator serves webhooks (no errors, sample-pg reconciles):
kubectl logs -n everest-system -l app=everest-operator -c manager --tail=20

# 4. TEST: create a PG cluster with proxy.replicas: 0
cat <<'EOF' | kubectl apply -f -
apiVersion: everest.percona.com/v1alpha1
kind: DatabaseCluster
metadata: { name: pg-noproxy, namespace: everest }
spec:
  engine:
    type: postgresql
    version: "16.11"
    replicas: 1
    storage: { size: 1Gi }
    resources: { cpu: "500m", memory: 512M }
  proxy: { type: pgbouncer, replicas: 0 }
EOF

# 5. EXPECTED RESULTS:
kubectl get perconapgcluster pg-noproxy -n everest -o jsonpath='pgbouncer.replicas={.spec.proxy.pgBouncer.replicas}{"\n"}'  # => 0
kubectl get pods   -n everest | grep pg-noproxy           # only pg-noproxy-instance* ; NO -pgbouncer pod
kubectl get deploy -n everest | grep pg-noproxy-pgbouncer # Deployment READY 0/0 (or absent) — must NOT be 1/1
kubectl get databasecluster pg-noproxy -n everest         # should reach STATUS ready
kubectl get pods -n everest | grep postgresql-operator    # MUST stay Running (no CrashLoop)

# 6. Cleanup test (optional):
kubectl delete databasecluster pg-noproxy -n everest
```

If step 5 shows the PG operator crashing again, the proxy went nil somewhere — re-check that
`applier.go Proxy()` was reverted (no `pg.Spec.Proxy = nil`) and that the deployed image is v3.

## Files changed (operator repo, uncommitted)
- `api/everest/v1alpha1/databasecluster_types.go` — Minimum 1→0 on Proxy.Replicas.
- `cmd/main.go` — re-enabled DatabaseCluster webhook registration.
- `config/crd/bases/everest.percona.com_databaseclusters.yaml` + `*_deepcopy.go` — regenerated.
- `bin/img/{manager,data-importer,migrator,Dockerfile.fast}` — host-built artifacts (gitignore-able).

## Docs deliverables (already complete)
- `README.md` — minimal install + DatabaseCluster usage.
- `dev.md` — GENERIC build/deploy guide (no feature-specific content, per user request).
- `manifests/01..05` — sample PG DatabaseClusters.
