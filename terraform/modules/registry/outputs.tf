output "registry_url" {
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.llm_repo.repository_id}"
  description = "Artifact Registry Docker URL"
}
