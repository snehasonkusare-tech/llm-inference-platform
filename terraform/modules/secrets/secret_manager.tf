resource "google_secret_manager_secret" "hf_token" {
  secret_id = "huggingface-token"
  project   = var.project_id

  replication {
    auto {}
  }
}

# After apply, add your HuggingFace token:
# echo -n "hf_xxxx" | gcloud secrets versions add huggingface-token --data-file=-
