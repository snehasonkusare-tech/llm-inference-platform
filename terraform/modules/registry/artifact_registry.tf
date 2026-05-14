resource "google_artifact_registry_repository" "llm_repo" {
  location      = var.region
  repository_id = "llm-platform"
  project       = var.project_id
  format        = "DOCKER"
  description   = "LLM inference platform Docker images"
}
