Install

```bash
curl -s https://api.github.com/repos/fullstorydev/grpcurl/releases/latest \
| grep browser_download_url \
| grep "$(uname -s | tr '[:upper:]' '[:lower:]')_x86_64.tar.gz" \
| cut -d '"' -f 4 \
| xargs curl -L -o /tmp/grpcurl.tar.gz && \
tar -xzf /tmp/grpcurl.tar.gz -C /usr/local/bin grpcurl && \
rm /tmp/grpcurl.tar.gz

grpcurl -version

```

RPC call inside POD, we have to add `reflection.Register(grpcServer)` in the grpc server code:
```bash

grpcurl -plaintext -unix -authority dummy unix:/run/topolvm/lvmd.sock list
```

```bash
grpcurl -plaintext -unix -authority dummy unix:/run/topolvm/lvmd.sock describe proto.VGService

proto.VGService is a service:
service VGService {
  rpc GetFreeBytes ( .proto.GetFreeBytesRequest ) returns ( .proto.GetFreeBytesResponse );
  rpc GetLVList ( .proto.GetLVListRequest ) returns ( .proto.GetLVListResponse );
  rpc Watch ( .proto.Empty ) returns ( stream .proto.WatchResponse );
}


```
```bash
grpcurl -plaintext -unix -authority dummy unix:/run/topolvm/lvmd.sock describe proto.GetLVListRequest
proto.GetLVListRequest is a message:

message GetLVListRequest {
  string device_class = 1;
}


```
Here taking VolumeSnapshot, It create LV with `thin` device class:

```bash
grpcurl -plaintext -unix -authority dummy   -d '{"device_class": "thin"}'   unix:/run/topolvm/lvmd.sock proto.VGService.GetLVList

{
  "volumes": [
    {
      "name": "1d3fa7cb-dbe1-4885-9e9f-402628c6e13c",
      "devMajor": 252,
      "devMinor": 5,
      "tags": [
        ""
      ],
      "sizeBytes": "1073741824",
      "path": "/dev/myvg1/1d3fa7cb-dbe1-4885-9e9f-402628c6e13c",
      "attr": "Vri-a-tz--"
    },
    {
      "name": "1c82c978-3a45-42da-9c6e-170642af18ac",
      "devMajor": 252,
      "devMinor": 4,
      "tags": [
        ""
      ],
      "sizeBytes": "1073741824",
      "path": "/dev/myvg1/1c82c978-3a45-42da-9c6e-170642af18ac",
      "attr": "Vwi-aotz--"
    }
  ]
}

```
here,
- volumeHandle: 1c82c978-3a45-42da-9c6e-170642af18ac
- snapshotHandle: 1d3fa7cb-dbe1-4885-9e9f-402628c6e13c


From Node,

```bash
lsblk -o NAME,KNAME,MOUNTPOINT

NAME                                                 KNAME MOUNTPOINT
sda                                                  sda   
├─myvg1-pool0_tmeta                                  dm-0  
│ └─myvg1-pool0-tpool                                dm-2  
│   ├─myvg1-pool0                                    dm-3  
│   ├─myvg1-1c82c978--3a45--42da--9c6e--170642af18ac dm-4  /var/lib/kubelet/pods/1c659500-dbc8-4484-84a3-ad3f49bb8400/volumes/kubernetes.io~csi/pvc-656689c9-2afe-4401-
│   └─myvg1-1d3fa7cb--dbe1--4885--9e9f--402628c6e13c dm-5  
└─myvg1-pool0_tdata                                  dm-1  
  └─myvg1-pool0-tpool                                dm-2  
    ├─myvg1-pool0                                    dm-3  
    ├─myvg1-1c82c978--3a45--42da--9c6e--170642af18ac dm-4  /var/lib/kubelet/pods/1c659500-dbc8-4484-84a3-ad3f49bb8400/volumes/kubernetes.io~csi/pvc-656689c9-2afe-4401-
    └─myvg1-1d3fa7cb--dbe1--4885--9e9f--402628c6e13c dm-5  

```


Inside LVM Pod:

```bash
apt update
apt install lvm2 util-linux

mkdir /mnt/snapshot-lv
mount -o ro,norecovery -t xfs /dev/myvg1/1d3fa7cb-dbe1-4885-9e9f-402628c6e13c /mnt/snapshot-lv
```



Debug in TopoLVM:

```bash
################### LogicalVolume: ThinSnapshot ####################
###### Args: [lvcreate -s -k n -n 80057918-1ee9-494a-960e-810551a50f4a myvg1/1d3fa7cb-dbe1-4885-9e9f-402628c6e13c]
{"level":"info","ts":"2025-10-07T12:32:08Z","msg":"Logical volume \"80057918-1ee9-494a-960e-810551a50f4a\" created."}
################### LogicalVolume: Activate ####################
###### Access: rw
###### Args: [lvchange -k n -a y /dev/myvg1/80057918-1ee9-494a-960e-810551a50f4a]

```

```bash
➤ kubectl get volumesnapshotcontents.snapshot.storage.k8s.io  snapcontent-acbf6f96-84a8-4a1a-8c03-e2c32a6f5385 -o yaml

lvscan

mount -o ro,norecovery -t xfs /dev/myvg1/73df3812-d643-42d1-9e2e-f20772c34dc5 /mnt/mg-snapshot-lv

cd /mnt/mg-snapshot-lv
ls


WiredTiger                             collection-24-14506254467221594773.wt  index-1-14506254467221594773.wt   index-37-14506254467221594773.wt
WiredTiger.backup                      collection-27-14506254467221594773.wt  index-11-14506254467221594773.wt  index-39-14506254467221594773.wt
WiredTiger.lock                        collection-28-14506254467221594773.wt  index-13-14506254467221594773.wt  index-41-14506254467221594773.wt
WiredTiger.turtle                      collection-30-14506254467221594773.wt  index-18-14506254467221594773.wt  index-42-14506254467221594773.wt
WiredTiger.wt                          collection-32-14506254467221594773.wt  index-19-14506254467221594773.wt  index-44-14506254467221594773.wt
WiredTigerHS.wt                        collection-35-14506254467221594773.wt  index-21-14506254467221594773.wt  index-46-14506254467221594773.wt
_mdb_catalog.wt                        collection-38-14506254467221594773.wt  index-23-14506254467221594773.wt  index-48-14506254467221594773.wt
collection-0-14506254467221594773.wt   collection-4-14506254467221594773.wt   index-25-14506254467221594773.wt  index-49-14506254467221594773.wt
collection-10-14506254467221594773.wt  collection-40-14506254467221594773.wt  index-26-14506254467221594773.wt  index-5-14506254467221594773.wt
collection-12-14506254467221594773.wt  collection-43-14506254467221594773.wt  index-29-14506254467221594773.wt  index-7-14506254467221594773.wt
collection-16-14506254467221594773.wt  collection-45-14506254467221594773.wt  index-3-14506254467221594773.wt   index-9-14506254467221594773.wt
collection-17-14506254467221594773.wt  collection-47-14506254467221594773.wt  index-31-14506254467221594773.wt  journal
collection-2-14506254467221594773.wt   collection-6-14506254467221594773.wt   index-33-14506254467221594773.wt  mongod.lock
collection-20-14506254467221594773.wt  collection-8-14506254467221594773.wt   index-34-14506254467221594773.wt  sizeStorer.wt
collection-22-14506254467221594773.wt  diagnostic.data                        index-36-14506254467221594773.wt  storage.bson

```

## Restic vs Kopia
- https://cloudcasa.io/blog/comparing-restic-vs-kopia-for-kubernetes-data-movement/