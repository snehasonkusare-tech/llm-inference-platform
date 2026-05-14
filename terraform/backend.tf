terraform {
  backend "gcs" {
    bucket = "my-llm-platform-tf-state"
    prefix = "llm-platform/state"
  }
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}