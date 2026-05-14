resource "google_container_node_pool" "cpu_pool" {
  name     = "cpu-pool"
  cluster  = google_container_cluster.primary.id
  location = var.region
  project  = var.project_id

  autoscaling {
    min_node_count = 1
    max_node_count = 5
  }

  node_config {
    machine_type = var.cpu_machine_type
    disk_size_gb = 100
    disk_type    = "pd-ssd"
    preemptible  = true

    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    service_account = var.gke_sa_email

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    labels = {
      pool = "cpu"
      env  = var.environment
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

resource "google_container_node_pool" "gpu_pool" {
  name     = "gpu-pool"
  cluster  = google_container_cluster.primary.id
  location = var.region
  project  = var.project_id

  autoscaling {
    min_node_count = 0
    max_node_count = 4
  }

  node_config {
    machine_type = var.gpu_machine_type
    disk_size_gb = 200
    disk_type    = "pd-ssd"
    spot         = var.environment == "dev" ? true : false

    guest_accelerator {
      type  = "nvidia-tesla-t4"
      count = 1
      gpu_driver_installation_config {
        gpu_driver_version = "LATEST"
      }
    }

    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    service_account = var.gke_sa_email

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    labels = {
      pool = "gpu"
      env  = var.environment
    }

    taint {
      key    = "nvidia.com/gpu"
      value  = "present"
      effect = "NO_SCHEDULE"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}
