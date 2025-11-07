### Create a thin pool of LVM beforehand, because TopoLVM doesn't create one. For example:
```bash
lsblk # Pick the disk to use, e.g., /dev/sda
pvcreate /dev/sda # Initialize the physical volume
vgcreate myvg1 /dev/sda # Create a volume group named myvg1
lvcreate -T -n pool0 -L 50G myvg1 # Create a thin pool named pool0 with size 4G in the volume group myvg1
```

### Install VolumeSnapshot CRDs and the cluster-wide controller:
```bash
kubectl kustomize https://github.com/kubernetes-csi/external-snapshotter/client/config/crd | kubectl create -f -
kubectl -n kube-system kustomize https://github.com/kubernetes-csi/external-snapshotter/deploy/kubernetes/snapshot-controller | kubectl create -f -
```

### Install TopoLVM
```bash
helm repo add topolvm https://topolvm.github.io/topolvm
helm repo update
kubectl create namespace topolvm-system
kubectl label namespace topolvm-system topolvm.io/webhook=ignore
kubectl label namespace kube-system topolvm.io/webhook=ignore
helm install --namespace=topolvm-system topolvm topolvm/topolvm --values ./values.yaml
```

