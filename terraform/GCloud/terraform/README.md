# GKE + VolumeSnapshot Terraform

Provisions a regional GKE cluster wired for CSI VolumeSnapshots:
VPC (VPC-native) → GKE cluster with the Compute Engine PD CSI driver → a
`StorageClass`. The `VolumeSnapshotClass` is applied with kubectl after apply
(see below for why).

---

## Prerequisites

| Tool | Minimum version |
|---|---|
| Terraform | 1.5 |
| gcloud CLI | latest, authenticated |
| kubectl | 1.28+ |

Authenticate and set application-default credentials so Terraform and the
kubernetes provider can talk to GCP:

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project <YOUR_PROJECT_ID>
```

Enable the required APIs once per project:

```bash
gcloud services enable container.googleapis.com compute.googleapis.com
```

---

## Module Overview

```
modules/
├── network/ — custom-mode VPC + one subnet with two secondary ranges
│              (pods + services) for a VPC-native cluster, Cloud Router + NAT
└── gke/     — regional GKE cluster (default node pool removed) + a managed
               node pool. Enables the PD CSI driver addon and Workload Identity.

manifests/    — VolumeSnapshotClass + source/restore test YAMLs (kubectl apply)
```

### How VolumeSnapshot support is turned on

VolumeSnapshots need three things on the cluster:

1. **A CSI driver that supports snapshots** — `pd.csi.storage.gke.io`.
2. **The snapshot CRDs** (`snapshot.storage.k8s.io`).
3. **The snapshot-controller.**

On GKE all three come from a single addon. The `gke` module sets:

```hcl
addons_config {
  gce_persistent_disk_csi_driver_config { enabled = true }
}
```

GKE then installs the driver, the CRDs, and the controller for you — there is
nothing to helm-install. You only supply a `StorageClass` (created by Terraform)
and a `VolumeSnapshotClass` (applied via kubectl).

### Why the VolumeSnapshotClass is not created by Terraform

`VolumeSnapshotClass` is a CRD. The `kubernetes_manifest` resource reads the
target CRD's schema at **plan** time. On a first apply the
`snapshot.storage.k8s.io` CRDs don't exist yet (the cluster isn't built), so the
plan fails with `no matches for kind VolumeSnapshotClass`. `depends_on` only
orders apply, not plan. Applying the class with kubectl after the cluster exists
sidesteps this — see the one-liner below.

---

## Deploy

```bash
# 1. Copy and edit the example vars file
cp terraform.tfvars.example terraform.tfvars
# Set project_id, region, node sizes, etc.

# 2. (Optional) pass the project via env instead of the file
export TF_VAR_project_id="my-gcp-project"

# 3. Init and apply
terraform init
terraform apply
```

Apply takes roughly **8–12 minutes** (cluster + node pool creation dominates).

### Configure kubectl after apply

```bash
$(terraform output -raw kubeconfig_command)
# equivalently:
gcloud container clusters get-credentials \
  $(terraform output -raw cluster_name) \
  --region $(terraform output -raw cluster_location) \
  --project <YOUR_PROJECT_ID>
```

### Apply the VolumeSnapshotClass

```bash
kubectl apply -f manifests/volumesnapshotclass.yaml
kubectl get volumesnapshotclass
```

### Verify snapshot support is live

```bash
# StorageClass created by Terraform
kubectl get storageclass csi-gce-pd-ssd

# CRDs installed by GKE
kubectl get crd | grep snapshot.storage.k8s.io

# snapshot-controller running
kubectl get pods -n kube-system | grep -i snapshot
```

You should see `volumesnapshots`, `volumesnapshotcontents`, and
`volumesnapshotclasses` CRDs. Run the full end-to-end test in
[../volumesnapshot-test.md](../volumesnapshot-test.md).

---

## Running more than one cluster (workspaces)

One Terraform state manages **one** cluster. Renaming `cluster_name` in the same
state does **not** create a second cluster — it plans to destroy the first and
build a new one (`N to add, N to destroy`), and you'll also hit
`dial tcp 127.0.0.1:80: connection refused` because the kubernetes provider's
endpoint becomes unknown mid-replace.

To run a second cluster, give it its **own state** with a Terraform workspace and
its own var-file. A workspace is a separate state file; a var-file passed with
`-var-file` overrides the auto-loaded `terraform.tfvars`.

```
default workspace   ── state ──►  cluster A  (terraform.tfvars: name_prefix=anisur, cluster_name=kubestash-vs)
cluster-b workspace ── state ──►  cluster B  (cluster-b.tfvars:  name_prefix=...-b, cluster_name=kubestash-vs2)
```

`terraform.tfvars` auto-loads in **every** workspace, so keep only cluster A's
identity there. Put cluster B's distinct values in `cluster-b.tfvars` and pass it
explicitly. `name_prefix` MUST differ between clusters — it names the
VPC/subnet/router/NAT/node-pool, which would otherwise collide in GCP.

```bash
# Cluster A lives in the default workspace — leave terraform.tfvars = A's identity.

# 1. New isolated state for cluster B
terraform workspace new cluster-b

# 2. Its var-file (distinct name_prefix + cluster_name)
cp cluster-b.tfvars.example cluster-b.tfvars

# 3. Apply B — the -var-file overrides terraform.tfvars
terraform apply -var-file=cluster-b.tfvars

# 4. Post-apply, per cluster
$(terraform output -raw kubeconfig_command)
kubectl apply -f manifests/volumesnapshotclass.yaml
```

Switching between them:

```bash
terraform workspace list             # * marks the active one
terraform workspace select default   # operate on cluster A
terraform workspace select cluster-b # operate on cluster B (remember -var-file)
```

> Always pass `-var-file=cluster-b.tfvars` for plan/apply/destroy in the
> `cluster-b` workspace, or it will fall back to `terraform.tfvars` (cluster A's
> values) against cluster B's state and plan a replace.

### Creating both clusters at the same time

A workspace is only *selected* per working directory — the choice is stored in
`.terraform/environment`, a single shared file. So you can't run two
`terraform apply` processes from the same directory after `workspace select`,
because both would read the same pointer.

Use the `TF_WORKSPACE` environment variable instead: it selects the workspace
**per process** without touching `.terraform/environment`, so two applies can run
concurrently from the same directory. Each workspace has its own state file and
its own state lock, so they don't collide.

```bash
# create the workspaces once (or `terraform workspace select`/`new` beforehand)
terraform workspace new cluster-a   # if A isn't already in a named workspace
terraform workspace new cluster-b

# fire both applies in parallel — each pins its workspace via env
TF_WORKSPACE=cluster-a terraform apply -auto-approve -var-file=cluster-a.tfvars &
TF_WORKSPACE=cluster-b terraform apply -auto-approve -var-file=cluster-b.tfvars &
wait   # block until both finish
```

Notes:

- `TF_WORKSPACE` **overrides** any selected workspace for that command; you don't
  run `terraform workspace select` at all.
- Give **each** cluster its own var-file (`cluster-a.tfvars`, `cluster-b.tfvars`)
  with a distinct `name_prefix` + `cluster_name`. Don't rely on the auto-loaded
  `terraform.tfvars` when running in parallel — be explicit.
- Cluster A already lives in the `default` workspace from earlier applies. To
  bring it under a named `cluster-a` workspace instead, either recreate it there
  or `terraform state mv`/pull-push its state; simplest is to leave A in
  `default` and only add B.

> If you already have cluster A running, you do **not** need this — just create B
> (previous section). Concurrent apply only matters when building two (or more)
> fresh clusters together.

Tear down just cluster B:

```bash
terraform workspace select cluster-b
terraform destroy -var-file=cluster-b.tfvars
terraform workspace select default
terraform workspace delete cluster-b
```

---

## Applying a single module

```bash
terraform apply -target=module.network   # network first
terraform apply -target=module.gke       # then the cluster (needs network)
```

`-target` does **not** auto-apply upstream dependencies — target them in order.

---

## Common commands

```bash
terraform fmt -recursive          # format
terraform validate                # syntax/type check
terraform plan                    # preview
terraform apply                   # create/update
terraform output                  # show outputs
terraform destroy                 # tear everything down
```

`deletion_protection = false` is set on the cluster so `terraform destroy`
removes it without a manual flag flip.

---

## Debug

```bash
# Which identity is Terraform using?
gcloud auth list
gcloud config get-value project

# Cluster reachable?
gcloud container clusters list
kubectl get nodes

# PD CSI driver / snapshot controller health
kubectl get pods -n kube-system -l k8s-app=gcp-compute-persistent-disk-csi-driver
kubectl get pods -n kube-system | grep -i snapshot

# Verbose Terraform logs
export TF_LOG=DEBUG
export TF_LOG_PATH=./tf-debug.log
terraform apply
```

### Common errors and fixes

**`Error: googleapi: Error 403 ... has not been used in project`**
— Enable the API: `gcloud services enable container.googleapis.com compute.googleapis.com`.

**`Error: no matches for kind "VolumeSnapshotClass"`**
— You tried to create the class in Terraform. It must be applied via kubectl
after the cluster exists — see above.

**`Error 400: Master version ... unsupported`**
— The `kubernetes_version` prefix isn't offered on the chosen release channel.
Leave `kubernetes_version = ""` to take the channel default, or pick a supported
prefix from `gcloud container get-server-config --region <region>`.

**Snapshot stuck with `readyToUse: false`**
— The snapshot is still uploading to Cloud Storage. Watch it:
`kubectl get volumesnapshot -n demo -w`.

---

## Key variables

| Variable | Default | Description |
|---|---|---|
| `project_id` | — (required) | GCP project ID |
| `region` | `us-central1` | GCP region (regional control plane) |
| `name_prefix` | `kubestash-gke` | Prefix for all resource names |
| `subnet_cidr` | `10.10.0.0/20` | Node subnet primary CIDR |
| `pods_cidr` | `10.20.0.0/16` | Secondary range for pods |
| `services_cidr` | `10.30.0.0/20` | Secondary range for services |
| `cluster_name` | `kubestash-vs` | GKE cluster name |
| `node_locations` | `["us-central1-a"]` | Zones for nodes |
| `kubernetes_version` | `""` | Version prefix; empty = channel default |
| `release_channel` | `REGULAR` | RAPID / REGULAR / STABLE / UNSPECIFIED |
| `node_machine_type` | `e2-standard-4` | Node machine type |
| `node_count` | `1` | Nodes **per zone** |
| `node_disk_type` | `pd-ssd` | Node boot disk type |
| `node_disk_size_gb` | `100` | Node boot disk size |
