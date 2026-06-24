# OpenEverest — Build & Deploy Custom Operator Code

Generic workflow: after you edit the OpenEverest source, rebuild the operator image and
deploy it to a running cluster.

> Tested with a remote k3s cluster (containerd), Docker, Go 1.26.

---

## Repositories

Local checkout under `~/go/src/openeverest/`:

| Repo | Purpose |
|------|---------|
| `openeverest-operator` | The Everest operator (`everest-operator` Deployment). Usually what you edit. |
| `openeverest` | The Everest API server + web UI (`everest-server` Deployment). |
| `helm-charts` | The `everest` Helm chart (CRDs, OLM install, Deployments). |

Running Deployments live in namespace `everest-system`. The operator image is
`ghcr.io/openeverest/openeverest-operator:<version>`.

---

## 1. Edit, regenerate, verify

```bash
cd ~/go/src/openeverest/openeverest-operator

# If you changed anything under api/**_types.go (fields or +kubebuilder markers),
# regenerate the CRDs and deepcopy code — otherwise the cluster CRD won't match the types.
make manifests generate     # writes config/crd/bases/*.yaml and zz_generated.deepcopy.go

go build ./...              # compile
go vet ./...               # static checks
make test                  # unit tests (optional)
```

---

## 2. Build the image

### Standard way
```bash
make docker-build IMG=<registry>/<image>:<tag> VERSION=<version>
# = docker build --build-arg FLAGS="-X .../consts.Version=<version>" -t <IMG> .
```

> Note: the upstream `Dockerfile` runs `go mod download` inside a fresh `golang` container
> (cold module cache) and builds the binaries with `go build -a` (full rebuild). On a loaded
> machine / slow link this can take many minutes.

### Fast way (dev iteration)
Build the binaries on the host (warm module cache, no `-a`), then bake a thin image that
copies them onto the same distroless base:
```bash
cd ~/go/src/openeverest/openeverest-operator
mkdir -p bin/img
FLAGS="-X 'github.com/percona/everest-operator/internal/consts.Version=<version>'"
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o bin/img/manager       ./cmd/main.go
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o bin/img/data-importer ./internal/data-importer/main.go
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags "$FLAGS" -o bin/img/migrator ./internal/migrate/main.go

cat > bin/img/Dockerfile.fast <<'DOCKER'
FROM gcr.io/distroless/static:nonroot
WORKDIR /
COPY manager .
COPY data-importer .
COPY migrator .
USER 65532:65532
ENTRYPOINT ["/manager"]
DOCKER

docker build -f bin/img/Dockerfile.fast -t <registry>/<image>:<tag> bin/img/
```
Match `GOARCH` to the cluster node's architecture (e.g. `amd64` for a standard GKE/GCE node).

---

## 3. Get the image to the cluster

Pick the path that matches your cluster:

### A. Your own registry (Docker Hub / GHCR / GCR / ECR …) — for remote clusters
```bash
docker login                     # once
docker push <registry>/<image>:<tag>
# or, with make: make docker-push IMG=<registry>/<image>:<tag>
```

### B. Public ephemeral registry (no login) — quick remote tests
```bash
# ttl.sh tags must include a TTL, e.g. :24h. Image is publicly pullable while it lives.
docker tag <local-image> ttl.sh/<name>:24h && docker push ttl.sh/<name>:24h
```

### C. Local cluster (node containerd reachable)
```bash
k3d   image import -c <cluster> <IMG>           # k3d
kind  load docker-image <IMG> --name <cluster>  # kind
docker save <IMG> | sudo k3s ctr images import - # local k3s
```

> Use a **new tag** for each build. With `imagePullPolicy: IfNotPresent`, reusing a tag
> means the node keeps the cached old image.

---

## 4. Deploy the new image

```bash
export KUBECONFIG=/path/to/kubeconfig

# (a) If you changed api types/markers, apply the regenerated CRD first.
#     Use server-side apply — these CRDs are large.
kubectl apply --server-side --force-conflicts \
  -f config/crd/bases/everest.percona.com_databaseclusters.yaml

# (b) Point the Deployment at your image. The container is "manager"; the
#     migration init container is "crs-migration" — update both for consistency.
kubectl set image deploy/everest-operator -n everest-system \
  manager=<IMG> crs-migration=<IMG>

# (c) Roll out and confirm.
kubectl rollout status deploy/everest-operator -n everest-system
kubectl get pod -n everest-system -l app=everest-operator \
  -o jsonpath='{.items[0].spec.containers[0].image}{"\n"}'
kubectl logs -n everest-system -l app=everest-operator -c manager --tail=20
```

> Helm/OLM may revert the image or CRD on the next `helm upgrade`/reconcile. For a
> permanent change, publish a real image and set it via the chart
> (`--set operator.image=<IMG>`) and ship CRD changes in `helm-charts`.

### Editing `everest-server` (API/UI) instead
Same flow in `~/go/src/openeverest/openeverest`: build & push an image, then
`kubectl set image deploy/everest-server -n everest-system everest=<IMG>`.

---

## 5. Revert

```bash
kubectl set image deploy/everest-operator -n everest-system \
  manager=ghcr.io/openeverest/openeverest-operator:<version> \
  crs-migration=ghcr.io/openeverest/openeverest-operator:<version>
# re-apply the stock CRD if you changed it (e.g. from helm template), then:
git -C ~/go/src/openeverest/openeverest-operator checkout -- api internal config cmd
```

---

## Quick reference

| Task | Command |
|------|---------|
| Regenerate CRDs + deepcopy | `make manifests generate` |
| Compile / vet / test | `go build ./...` · `go vet ./...` · `make test` |
| Build image (standard) | `make docker-build IMG=<img> VERSION=<v>` |
| Build image (fast) | host `go build` + `docker build -f bin/img/Dockerfile.fast` |
| Push image | `docker push <img>` (or `make docker-push IMG=<img>`) |
| Apply CRD | `kubectl apply --server-side --force-conflicts -f config/crd/bases/<crd>.yaml` |
| Swap operator image | `kubectl set image deploy/everest-operator -n everest-system manager=<img> crs-migration=<img>` |
| Roll status | `kubectl rollout status deploy/everest-operator -n everest-system` |
