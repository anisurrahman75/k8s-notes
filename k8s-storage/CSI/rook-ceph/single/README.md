### Installation Guideline:

```bash
export ROOK_REPO=/home/anisur/go/src/rook/rook

cd $ROOK_REPO/deploy/examples

kubectl apply -f crds.yaml -f common.yaml -f csi-operator.yaml -f operator.yaml


echo "apiVersion: ceph.rook.io/v1
kind: CephCluster
metadata:
  name: rook-ceph
  namespace: rook-ceph
spec:
  cephVersion:
    image: quay.io/ceph/ceph:v19.2.3
  dataDirHostPath: /var/lib/rook
  mon:
    count: 1
    allowMultiplePerNode: true
  mgr:
    count: 1
  dashboard:
    enabled: true
    ssl: true
  storage:
    useAllNodes: false
    useAllDevices: false
    nodes:
      - name: "anisur" ## Change it to your node name `kubectl get nodes` to check the node name. It will be an array of nodes.
        devices:
          - name: "sda" ## SSH the node `lsblk` to check and complete empty disk with partision. 
" | kubectl apply -f -


cd $ROOK_REPO/deploy/examples/csi/rbd


kubectl apply -f storageclass-test.yaml,raw-block-pod.yaml,raw-block-pvc.yaml

```

### Troubleshoot while Installing ROOK

```bash
sudo rm -rf /var/lib/rook/*
sudo rm -rf /var/lib/ceph/*

sudo sgdisk --zap-all /dev/sda

sudo wipefs -a /dev/sda

sudo dd if=/dev/zero of=/dev/sda bs=1M count=100      # first 100MB
sudo dd if=/dev/zero of=/dev/sda bs=1M count=100 seek=$(( $(blockdev --getsz /dev/sda)/2048 - 100 ))   # last 

lsblk -f /dev/sda

```