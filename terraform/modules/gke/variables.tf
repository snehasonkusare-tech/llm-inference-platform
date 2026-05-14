variable "region" {
  type        = string
  description = "GCP region"
}

variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "network_id" {
  type        = string
  description = "VPC network ID"
}

variable "cpu_subnet_id" {
  type        = string
  description = "CPU subnet ID"
}

variable "gke_sa_email" {
  type        = string
  description = "GKE service account email"
}

variable "environment" {
  type        = string
  description = "Environment (dev/prod)"
  default     = "dev"
}

variable "cpu_machine_type" {
  type        = string
  description = "Machine type for CPU node pool"
  default     = "n2-standard-8"
}

variable "gpu_machine_type" {
  type        = string
  description = "Machine type for GPU node pool"
  default     = "g2-standard-24"
}
