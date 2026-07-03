# GKE VolumeSnapshot: snapshot in Cluster A, restore in Cluster B

Goal: take a CSI VolumeSnapshot of a PVC in **Cluster A**, then provision a PVC
from that same snapshot in a **different** GKE cluster (**Cluster B**) and prove
the data survived the hop.

This works because the snapshot object you see in Kubernetes is only *metadata*.
The real data lives in a **project-global GCE persistent-disk snapshot** that
exists independently of any cluster:

```
  Cluster A (kubestash-vs)                         Cluster B (new cluster)
  ┌───────────────────────────┐                   ┌───────────────────────────┐
  │ source-pvc                 │                   │                           │
  │   │ write hello.txt        │                   │  imported VolumeSnapshot- │
  │   ▼                        │                   │  Content (static) ──┐     │
  │ VolumeSnapshot ────────┐   │                   │  imported Volume-   │     │
  │ VolumeSnapshotContent  │   │                   │  Snapshot ◄─────────┘     │
  └────────────────────────┼───┘                   │        │ dataSource       │
                           │                        │        ▼                  │
              points at    │        ┌───────────────┼──► restored-pvc ──► pod   │
                           ▼        │  same handle   │       (reads hello.txt)   │
     GCE snapshot:  projects/<proj>/global/snapshots/snapshot-<uid>             │
     (project-global — outlives Cluster A entirely)                             │
```

Both clusters must be in the **same GCP project** (the snapshot handle is
project-scoped) and both need the **PD CSI driver** enabled. Region/zone can
differ — GCE snapshots are global.

---

## Conditions (read once)

| Requirement | Why |
|---|---|
| Same GCP project | The `snapshotHandle` is `projects/<proj>/global/snapshots/...` — project-scoped. Cross-project needs IAM on the snapshot resource. |
| **`deletionPolicy: Retain`** on the source VolumeSnapshotClass / content | Otherwise deleting the snapshot in Cluster A (or deleting Cluster A) destroys the GCE snapshot and Cluster B has nothing to restore. |
| PD CSI driver on both clusters | Provided by the `GcePersistentDiskCsiDriver` addon — see [cluster-creation.md](cluster-creation.md). |
| `restoreSize` ≥ source | The restored PVC must request ≥ the snapshot's `restoreSize`. |

> `Retain` protects the GCE snapshot from Kubernetes — but it also means you must
> delete it manually when done: `gcloud compute snapshots delete snapshot-<uid>`.

---

## Part 1 — Cluster A: create the source volume and snapshot

Context into Cluster A:

```bash
gcloud container clusters get-credentials kubestash-vs \
  --region us-central1 --project appscode-testing
```

Create the namespace, source PVC, and a pod that writes a file:

```bash
kubectl create namespace demo
kubectl apply -f terraform/manifests/source-pvc.yaml
kubectl apply -f terraform/manifests/source-pod.yaml

kubectl wait --for=condition=Ready pod/source-pod -n demo --timeout=120s
kubectl exec -n demo source-pod -- cat /data/hello.txt      # note this string
```

Take the snapshot (its class uses `deletionPolicy: Retain`):

```bash
kubectl apply -f terraform/manifests/snapshot.yaml
kubectl get volumesnapshot -n demo -w                       # wait READYTOUSE=true
```

### Grab the two values Cluster B needs

```bash
# 1. The bound VolumeSnapshotContent name
VSC=$(kubectl get volumesnapshot -n demo source-pvc-snapshot \
        -o jsonpath='{.status.boundVolumeSnapshotContentName}')

# 2. The project-global GCE snapshot handle — THIS is what crosses clusters
kubectl get volumesnapshotcontent "$VSC" \
  -o jsonpath='{.status.snapshotHandle}{"\n"}'
# e.g. projects/appscode-testing/global/snapshots/snapshot-cccff36b-eb60-4639-b399-3f42e2eaf090
```

Confirm the underlying GCE snapshot exists independently of the cluster:

```bash
gcloud compute snapshots list --project appscode-testing
```

At this point Cluster A has done its job. The GCE snapshot will survive even if
you delete the VolumeSnapshot, the namespace, or the entire Cluster A — because
the class is `Retain`.

---

## Part 2 — Cluster B: import the snapshot and restore

Create/point at Cluster B and switch context to it:

```bash
# (if you don't have one yet, stand up a second cluster with the same Terraform,
#  changing cluster_name / region in terraform.tfvars, then:)
gcloud container clusters get-credentials <CLUSTER_B_NAME> \
  --region <CLUSTER_B_REGION> --project appscode-testing

kubectl config current-context      # make sure this is Cluster B!
```

Ensure Cluster B has the StorageClass and VolumeSnapshotClass:

```bash
kubectl apply -f terraform/manifests/volumesnapshotclass.yaml
kubectl get storageclass csi-gce-pd-ssd     # created by Terraform on Cluster B
kubectl create namespace demo
```

### Put the snapshot handle into the import manifest

Edit [terraform/manifests/import-existing-snapshot/1-import-vsc.yaml](terraform/manifests/import-existing-snapshot/1-import-vsc.yaml)
and set `spec.source.snapshotHandle` to the handle you copied from Cluster A. Or
patch it in place:

```bash
cd terraform/manifests/import-existing-snapshot
HANDLE=projects/appscode-testing/global/snapshots/snapshot-cccff36b-eb60-4639-b399-3f42e2eaf090
sed -i "s|snapshotHandle:.*|snapshotHandle: ${HANDLE}|" 1-import-vsc.yaml
```

### Apply the static import, then restore

```bash
# 1. Statically bound VolumeSnapshotContent -> the GCE snapshot handle
kubectl apply -f 1-import-vsc.yaml

# 2. VolumeSnapshot bound to that content (source is a content name, not a PVC)
kubectl apply -f 2-import-vs.yaml
kubectl get volumesnapshot -n demo imported-snapshot -w    # READYTOUSE=true

# 3. New PVC provisioned from the imported snapshot
kubectl apply -f 3-restored-pvc.yaml

# 4. Pod that mounts it and prints the file written back in Cluster A
kubectl apply -f 4-restored-pod.yaml
kubectl wait --for=condition=Ready pod/restored-pod -n demo --timeout=120s
kubectl logs -n demo restored-pod
kubectl exec -n demo restored-pod -- cat /data/hello.txt
```

If the string matches what `source-pod` wrote in Cluster A, the cross-cluster
snapshot restore works.

---

## How the static import differs from a same-cluster restore

| Same cluster (Part 1 style) | Cross cluster (Part 2 style) |
|---|---|
| `VolumeSnapshot.source.persistentVolumeClaimName` | `VolumeSnapshot.source.volumeSnapshotContentName` |
| CSI **creates** the VolumeSnapshotContent for you | **You** create the VolumeSnapshotContent, pointing at `snapshotHandle` |
| Binding is dynamic | Binding is static (pre-bound via `volumeSnapshotRef`) |

The pre-bind is a two-way handshake: the `VolumeSnapshotContent.volumeSnapshotRef`
names the `VolumeSnapshot`, and the `VolumeSnapshot.source.volumeSnapshotContentName`
names the content. Both must agree or it stays `readyToUse: false`.

---

## Cleanup

```bash
# Cluster B
kubectl delete -f terraform/manifests/import-existing-snapshot/ -n demo
kubectl delete namespace demo

# Cluster A
kubectl delete -f terraform/manifests/snapshot.yaml
kubectl delete -f terraform/manifests/source-pod.yaml
kubectl delete -f terraform/manifests/source-pvc.yaml
kubectl delete namespace demo

# The GCE snapshot is Retain — delete it explicitly when you're done with both
gcloud compute snapshots delete snapshot-cccff36b-eb60-4639-b399-3f42e2eaf090 \
  --project appscode-testing
```

---

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Imported `VolumeSnapshot` stuck `readyToUse: false` | The `volumeSnapshotRef` (in the content) and `volumeSnapshotContentName` (in the snapshot) don't match, or the namespace differs. They must reference each other exactly. |
| PVC `Pending`, event `snapshot ... not found` | Cluster B can't see the GCE snapshot — wrong project, or the handle was mistyped. Verify with `gcloud compute snapshots describe snapshot-<uid>`. |
| `rpc error ... PermissionDenied` on restore | Cluster B's node service account lacks read access to the snapshot — grant `roles/compute.storageAdmin` (or a snapshot-scoped role) in the project. |
| GCE snapshot gone after deleting Cluster A | The source class was `Delete`, not `Retain`. Re-run with `deletionPolicy: Retain` before deleting anything. |
| Restored pod can't find the file | `dataSource` on `restored-pvc` doesn't point at `imported-snapshot`, or the PVC bound before the import was ready. |

---

## Old Cluster VS and VSC (reference capture)

The concrete snapshot handle used in the examples above came from this capture on
Cluster A (`kubestash-vs`):

```text
# kubectl get volumesnapshot -n demo source-pvc-snapshot -o yaml (trimmed)
status:
  boundVolumeSnapshotContentName: snapcontent-cccff36b-eb60-4639-b399-3f42e2eaf090
  readyToUse: true
  restoreSize: 5Gi

# kubectl get volumesnapshotcontent snapcontent-cccff36b-... -o yaml (trimmed)
spec:
  deletionPolicy: Retain
  driver: pd.csi.storage.gke.io
  source:
    volumeHandle: projects/appscode-testing/zones/us-central1-a/disks/pvc-8f264fee-9ff7-4764-9190-6480746af36b
status:
  readyToUse: true
  restoreSize: 5368709120
  snapshotHandle: projects/appscode-testing/global/snapshots/snapshot-cccff36b-eb60-4639-b399-3f42e2eaf090
```

Note `snapshotHandle` is `global` (crosses clusters) while `volumeHandle` is
`zones/us-central1-a` (the original disk, cluster-local).

---

## Next: wire this into KubeStash

This proves raw CSI snapshots move between clusters. KubeStash drives the same
mechanism through a `BackupConfiguration` with `snapshotter: CSI` targeting the
`csi-gce-pd-snapshot-class`. See the repo's `volume-snapshots/` examples and
`backup-restore/` manifests for the KubeStash CRDs layered on top.
