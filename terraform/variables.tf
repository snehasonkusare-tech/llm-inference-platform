variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "zone" {
  type    = string
  default = "us-central1-a"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "gpu_machine_type" {
  type    = string
  default = "g2-standard-24"   # 1× NVIDIA L4, 24 vCPU, 96GB RAM
}

variable "cpu_machine_type" {
  type    = string
  default = "n2-standard-8"
}
