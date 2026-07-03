output "cluster_name" {
  value = module.gke.cluster_name
}

output "cluster_endpoint" {
  description = "GKE control plane endpoint"
  value       = module.gke.cluster_endpoint
}

output "cluster_location" {
  value = var.region
}

output "storage_class" {
  description = "StorageClass created for PD-backed PVCs"
  value       = kubernetes_storage_class_v1.pd_ssd.metadata[0].name
}

output "kubeconfig_command" {
  description = "Run this to update your local kubeconfig."
  value       = "gcloud container clusters get-credentials ${module.gke.cluster_name} --region ${var.region} --project ${var.project_id}"
}
