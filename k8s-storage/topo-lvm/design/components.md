## Learning Materials
- https://opensource.com/business/16/9/linux-users-guide-lvm
- https://linuxhandbook.com/lvm-guide/

## Go with topo-lvm


## Components

- `topolvm-controller`: CSI controller service.
- `topolvm-scheduler`: A [scheduler extender](https://github.com/kubernetes/design-proposals-archive/blob/main/scheduling/scheduler_extender.md) for TopoLVM.
- `topolvm-node`: CSI node service.
- `LVMd`: gRPC service to manage LVM volumes.



## LVMd
https://github.com/topolvm/topolvm/blob/main/pkg/lvmd/proto/lvmd.proto

A `UNIX domain socket` is like a `local-only IP socket`, but instead of `host:port`, you connect to a file path.

```protobuf
// Service to manage logical volumes of the volume group.
service LVService {
    // Create a logical volume.
    rpc CreateLV(CreateLVRequest) returns (CreateLVResponse);
    // Remove a logical volume.
    rpc RemoveLV(RemoveLVRequest) returns (Empty);
    // Resize a logical volume.
    rpc ResizeLV(ResizeLVRequest) returns (ResizeLVResponse);
    rpc CreateLVSnapshot(CreateLVSnapshotRequest) returns (CreateLVSnapshotResponse);
}

// Service to retrieve information of the volume group.
service VGService {
    // Get the list of logical volumes in the volume group.
    rpc GetLVList(GetLVListRequest) returns (GetLVListResponse);
    // Get the free space of the volume group in bytes.
    rpc GetFreeBytes(GetFreeBytesRequest) returns (GetFreeBytesResponse);
    // Stream the volume group metrics.
    rpc Watch(Empty) returns (stream WatchResponse);
}
```

## topolvm-node
`topolvm-node` implements `CSI node services` as well as miscellaneous control on `each Node`. It communicates with `LVMd` to watch changes in free space of a volume group and exports the information by annotating Kubernetes Node resource of the `running node`. In the meantime, it adds a finalizer to the Node to clean up PersistentVolumeClaims (PVC) bound on the node. It also works as a custom Kubernetes controller to implement `dynamic volume provisioning`.

## topolvm-controller
`topolvm-controller` implements CSI controller services. It also works as a custom Kubernetes controller to implement dynamic volume provisioning and resource cleanups.

## topolvm-scheduler




