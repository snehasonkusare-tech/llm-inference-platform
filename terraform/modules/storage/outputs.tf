output "bucket_name" {
  value       = google_storage_bucket.model_weights.name
  description = "GCS model weights bucket name"
}
