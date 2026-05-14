output "vpc_id" {
  value       = google_compute_network.llm_vpc.id
  description = "VPC network ID"
}

output "cpu_subnet_id" {
  value       = google_compute_subnetwork.cpu_subnet.id
  description = "CPU subnet ID"
}

output "gpu_subnet_id" {
  value       = google_compute_subnetwork.gpu_subnet.id
  description = "GPU subnet ID"
}
