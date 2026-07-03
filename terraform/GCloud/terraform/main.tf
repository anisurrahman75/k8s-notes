module "network" {
  source = "./modules/network"

  name_prefix   = var.name_prefix
  region        = var.region
  subnet_cidr   = var.subnet_cidr
  pods_cidr     = var.pods_cidr
  services_cidr = var.services_cidr
}

module "gke" {
  source = "./modules/gke"

  name_prefix        = var.name_prefix
  cluster_name       = var.cluster_name
  region             = var.region
  project_id         = var.project_id
  node_locations     = var.node_locations
  kubernetes_version = var.kubernetes_version
  release_channel    = var.release_channel

  network_name    = module.network.network_name
  subnet_name     = module.network.subnet_name
  pods_range_name = module.network.pods_range_name
  svc_range_name  = module.network.svc_range_name

  node_machine_type = var.node_machine_type
  node_count        = var.node_count
  node_disk_type    = var.node_disk_type
  node_disk_size_gb = var.node_disk_size_gb
}

# ── VolumeSnapshot support ────────────────────────────────────────────────────
# The PD CSI driver addon (enabled in the gke module) makes GKE auto-install the
# snapshot CRDs + snapshot-controller. We add a StorageClass here; the
# VolumeSnapshotClass (a CRD) is applied via kubectl after apply — see README.
#
# Why not create the VolumeSnapshotClass in Terraform? The kubernetes_manifest
# resource reads the target CRD's schema at *plan* time. On a first apply the
# snapshot.storage.k8s.io CRDs do not exist yet (the cluster isn't built), so the
# plan fails with "no matches for kind VolumeSnapshotClass". depends_on does not
# help — it only orders apply, not plan. Applying the manifest with kubectl after
# the cluster exists sidesteps this cleanly.

resource "kubernetes_storage_class_v1" "pd_ssd" {
  metadata {
    name = "csi-gce-pd-ssd"
  }
  storage_provisioner = "pd.csi.storage.gke.io"
  parameters = {
    type = "pd-ssd"
  }
  # WaitForFirstConsumer keeps the disk in the same zone as the pod that mounts it.
  volume_binding_mode    = "WaitForFirstConsumer"
  reclaim_policy         = "Delete"
  allow_volume_expansion = true

  depends_on = [module.gke]
}
