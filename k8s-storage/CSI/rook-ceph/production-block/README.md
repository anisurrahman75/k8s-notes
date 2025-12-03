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
    count: 3                       # 3 monitors for quorum in production
    allowMultiplePerNode: false    # Only 1 monitor per node recommended
  mgr:
    count: 2                       # 2 managers for high availability
  dashboard:
    enabled: true
    ssl: true
  storage:
    useAllNodes: false
    useAllDevices: false
    nodes:
      - name: "acdc-2-1"
        devices:
          - name: "nvme2n1"
          - name: "nvme1n1"
      - name: "acdc-2-2"
        devices:
          - name: "nvme2n1"
          - name: "nvme1n1"
      - name: "acdc-2-3"
        devices:
          - name: "nvme2n1"
          - name: "nvme1n1"
      - name: "acdc-2-4"
        devices:
          - name: "nvme2n1"
          - name: "nvme1n1"

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