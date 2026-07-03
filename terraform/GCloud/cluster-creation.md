# GKE Cluster Creation (with VolumeSnapshot support)

Two ways to stand up a GKE cluster that supports CSI VolumeSnapshots:

- **A. Terraform** — reproducible, recommended. Code lives in [terraform/](terraform/).
- **B. gcloud one-liner** — quick, throwaway clusters.

Either way the goal is the same: a cluster where the **Compute Engine PD CSI
driver** is enabled, because that addon is what makes GKE install the snapshot
CRDs (`snapshot.storage.k8s.io`) and the snapshot-controller.

```
 What VolumeSnapshots need on the cluster        Where it comes from on GKE
 ┌──────────────────────────────────────┐        ┌──────────────────────────┐
 │ 1. CSI driver with snapshot support   │ ─────► │ pd.csi.storage.gke.io     │
 │ 2. snapshot.storage.k8s.io CRDs       │ ─────► │ installed by the PD CSI   │
 │ 3. snapshot-controller                │ ─────► │ driver addon (all three)  │
 └──────────────────────────────────────┘        └──────────────────────────┘
```

---

## Prerequisites

```bash
gcloud auth login
gcloud auth application-default login          # needed for Terraform
gcloud config set project <YOUR_PROJECT_ID>
gcloud services enable container.googleapis.com compute.googleapis.com
```

| Tool | Minimum version |
|---|---|
| gcloud CLI | latest |
| kubectl | 1.28+ |
| Terraform (option A) | 1.5 |

---

## Option A — Terraform (recommended)

```bash
cd terraform

cp terraform.tfvars.example terraform.tfvars   # set project_id, region, sizes
export TF_VAR_project_id="my-gcp-project"       # or put it in the tfvars file

terraform init
terraform apply                                 # ~8–12 min
```

Get credentials and apply the VolumeSnapshotClass:

```bash
$(terraform output -raw kubeconfig_command)
kubectl apply -f manifests/volumesnapshotclass.yaml
```

Full command reference, single-module targeting, and debugging live in
[terraform/README.md](terraform/README.md).

---

## Option B — gcloud one-liner

```bash
gcloud container clusters create kubestash-vs \
  --region us-central1 \
  --node-locations us-central1-a \
  --num-nodes 1 \
  --machine-type e2-standard-4 \
  --disk-type pd-ssd \
  --disk-size 100 \
  --release-channel regular \
  --addons GcePersistentDiskCsiDriver \
  --workload-pool "$(gcloud config get-value project).svc.id.goog"
```

> `--addons GcePersistentDiskCsiDriver` is the important flag — it pulls in the
> driver, the snapshot CRDs, and the controller. On recent GKE versions the PD
> CSI driver is on by default, but passing it explicitly is safe and clear.

Get credentials:

```bash
gcloud container clusters get-credentials kubestash-vs \
  --region us-central1 --project <YOUR_PROJECT_ID>
```

Apply a StorageClass and the VolumeSnapshotClass:

```bash
kubectl apply -f terraform/manifests/volumesnapshotclass.yaml

# StorageClass (Terraform creates this for you in option A)
cat <<'EOF' | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: csi-gce-pd-ssd
provisioner: pd.csi.storage.gke.io
parameters:
  type: pd-ssd
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Retain
EOF
```

---

## Verify the cluster supports snapshots

```bash
kubectl get nodes

# CRDs installed by the PD CSI driver addon
kubectl get crd | grep snapshot.storage.k8s.io
#   volumesnapshotclasses.snapshot.storage.k8s.io
#   volumesnapshotcontents.snapshot.storage.k8s.io
#   volumesnapshots.snapshot.storage.k8s.io

# snapshot-controller pod
kubectl get pods -n kube-system | grep -i snapshot

# StorageClass + default VolumeSnapshotClass
kubectl get storageclass csi-gce-pd-ssd
kubectl get volumesnapshotclass
```

If all of the above are present, run the end-to-end backup/restore test in
[volumesnapshot-test.md](volumesnapshot-test.md).

---

## Tear down

```bash
# Option A
cd terraform && terraform destroy

# Option B
gcloud container clusters delete kubestash-vs --region us-central1
```
