# Regional GKE cluster, VPC-native. We remove the default node pool and manage a
# separate node pool so node config can be changed without recreating the cluster.

resource "google_container_cluster" "this" {
  name           = var.cluster_name
  location       = var.region
  node_locations = var.node_locations

  # Empty string lets the release channel choose the version.
  min_master_version = var.kubernetes_version != "" ? var.kubernetes_version : null

  release_channel {
    channel = var.release_channel
  }

  # Manage the node pool separately.
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = var.network_name
  subnetwork = var.subnet_name

  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.svc_range_name
  }

  # ── VolumeSnapshot support ──────────────────────────────────────────────────
  # Enabling the Compute Engine PD CSI driver makes GKE install the driver plus
  # the snapshot CRDs (snapshot.storage.k8s.io) and the snapshot-controller. This
  # is what allows VolumeSnapshot / VolumeSnapshotContent objects to work.
  addons_config {
    gce_persistent_disk_csi_driver_config {
      enabled = true
    }
  }

  # Workload Identity — handy if you later wire KubeStash to GCS via a GSA.
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Let `terraform destroy` remove the cluster without a manual flag flip.
  deletion_protection = false
}

resource "google_container_node_pool" "this" {
  name     = "${var.name_prefix}-pool"
  location = var.region
  cluster  = google_container_cluster.this.name

  # node_count is per-zone; total nodes = node_count * len(node_locations).
  node_count = var.node_count

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type = var.node_machine_type
    disk_type    = var.node_disk_type
    disk_size_gb = var.node_disk_size_gb

    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}
