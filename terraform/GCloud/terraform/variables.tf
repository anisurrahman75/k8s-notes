variable "project_id" {
  description = "GCP project ID. Pass via TF_VAR_project_id or terraform.tfvars."
}

variable "region" {
  default = "us-central1"
}

variable "name_prefix" {
  default = "kubestash-gke"
}

# ── Network ──────────────────────────────────────────────────────────────────

variable "subnet_cidr" {
  description = "Primary CIDR for the node subnet."
  default     = "10.10.0.0/20"
}

variable "pods_cidr" {
  description = "Secondary range for pods (VPC-native cluster)."
  default     = "10.20.0.0/16"
}

variable "services_cidr" {
  description = "Secondary range for services (VPC-native cluster)."
  default     = "10.30.0.0/20"
}

# ── GKE ──────────────────────────────────────────────────────────────────────

variable "cluster_name" {
  default = "kubestash-vs"
}

# Regional cluster control plane lives in `region`; nodes are placed in
# `node_locations`. Leave empty to let GKE pick zones in the region.
variable "node_locations" {
  type    = list(string)
  default = ["us-central1-a"]
}

# Exact control-plane version prefix (e.g. "1.30."). Empty = release channel default.
variable "kubernetes_version" {
  default = ""
}

variable "release_channel" {
  description = "One of RAPID, REGULAR, STABLE, or UNSPECIFIED."
  default     = "REGULAR"
}

variable "node_machine_type" {
  default = "e2-standard-4"
}

variable "node_count" {
  description = "Nodes per zone in node_locations."
  default     = 1
}

variable "node_disk_type" {
  default = "pd-ssd"
}

variable "node_disk_size_gb" {
  default = 100
}
