variable "name_prefix" {}
variable "cluster_name" {}
variable "region" {}
variable "project_id" {}
variable "node_locations" { type = list(string) }
variable "kubernetes_version" { default = "" }
variable "release_channel" { default = "REGULAR" }

variable "network_name" {}
variable "subnet_name" {}
variable "pods_range_name" {}
variable "svc_range_name" {}

variable "node_machine_type" {}
variable "node_count" {}
variable "node_disk_type" {}
variable "node_disk_size_gb" {}
