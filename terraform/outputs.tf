output "gke_cluster_name" {
  value       = module.gke.cluster_name
  description = "GKE cluster name"
}

output "gke_cluster_endpoint" {
  value       = module.gke.cluster_endpoint
  description = "GKE cluster endpoint"
  sensitive   = true
}

output "gcs_bucket_name" {
  value       = module.storage.bucket_name
  description = "GCS model weights bucket name"
}

output "artifact_registry_url" {
  value       = module.registry.registry_url
  description = "Artifact Registry Docker URL"
}

output "gke_sa_email" {
  value       = module.iam.gke_sa_email
  description = "GKE service account email"
}
