## Controllers

**topolvm-controller**

```go

type IdentityServer interface {
    GetPluginInfo(context.Context, *GetPluginInfoRequest) (*GetPluginInfoResponse, error)
    GetPluginCapabilities(context.Context, *GetPluginCapabilitiesRequest) (*GetPluginCapabilitiesResponse, error)
    Probe(context.Context, *ProbeRequest) (*ProbeResponse, error)
    mustEmbedUnimplementedIdentityServer()
}

type ControllerServer interface {
	CreateVolume(context.Context, *CreateVolumeRequest) (*CreateVolumeResponse, error)
	DeleteVolume(context.Context, *DeleteVolumeRequest) (*DeleteVolumeResponse, error)
	ControllerPublishVolume(context.Context, *ControllerPublishVolumeRequest) (*ControllerPublishVolumeResponse, error)
	ControllerUnpublishVolume(context.Context, *ControllerUnpublishVolumeRequest) (*ControllerUnpublishVolumeResponse, error)
	ValidateVolumeCapabilities(context.Context, *ValidateVolumeCapabilitiesRequest) (*ValidateVolumeCapabilitiesResponse, error)
	ListVolumes(context.Context, *ListVolumesRequest) (*ListVolumesResponse, error)
	GetCapacity(context.Context, *GetCapacityRequest) (*GetCapacityResponse, error)
	ControllerGetCapabilities(context.Context, *ControllerGetCapabilitiesRequest) (*ControllerGetCapabilitiesResponse, error)
	CreateSnapshot(context.Context, *CreateSnapshotRequest) (*CreateSnapshotResponse, error)
	DeleteSnapshot(context.Context, *DeleteSnapshotRequest) (*DeleteSnapshotResponse, error)
	ListSnapshots(context.Context, *ListSnapshotsRequest) (*ListSnapshotsResponse, error)
	ControllerExpandVolume(context.Context, *ControllerExpandVolumeRequest) (*ControllerExpandVolumeResponse, error)
	ControllerGetVolume(context.Context, *ControllerGetVolumeRequest) (*ControllerGetVolumeResponse, error)
	ControllerModifyVolume(context.Context, *ControllerModifyVolumeRequest) (*ControllerModifyVolumeResponse, error)
	mustEmbedUnimplementedControllerServer()
}
```

```go
func (r gRPCServerRunner) Start(ctx context.Context) error {
	err := os.Remove(r.sockFile)
	if err != nil && !os.IsNotExist(err) {
		return err
	}
	lis, err := net.Listen("unix", r.sockFile)
	if err != nil {
		return err
	}

	go func() {
		<-ctx.Done()
		r.srv.GracefulStop()
	}()

	return r.srv.Serve(lis)
}

//  Running server over unix socket, not in TCP/IP,PORT network
```

**csi-provisioner** Sidecar
```bash
external-provisioner: $(OUTPUT_DIR)/.csi-provisioner-$(EXTERNAL_PROVISIONER_VERSION)
	cp -f $< $(OUTPUT_DIR)/csi-provisioner
```

**Sidecar List**
```bash
CSI_SIDECARS = \
external-provisioner \
external-snapshotter \
external-resizer \
node-driver-registrar \
livenessprobe
```
A list of all CSI sidecars that TopoLVM bundles into its image.

When you run make build, it will build all these sidecars.

**csi-resizer** Sidecar
```bash
external-resizer: $(OUTPUT_DIR)/.csi-resizer-$(EXTERNAL_RESIZER_VERSION)
	cp -f $< $(OUTPUT_DIR)/csi-resizer
```

**csi-snapshotter** Sidecar
```bash
external-snapshotter: $(OUTPUT_DIR)/.csi-snapshotter-$(EXTERNAL_SNAPSHOTTER_VERSION)
	cp -f $< $(OUTPUT_DIR)/csi-snapshotter
```

**liveness-probe** sidecar
```bash
livenessprobe: $(OUTPUT_DIR)/.livenessprobe-$(LIVENESSPROBE_VERSION)
	cp -f $< $(OUTPUT_DIR)/livenessprobe
```

## Node

**topolvm-node**

**csi-register** Sidecar

**liveness-probe** sidecar


