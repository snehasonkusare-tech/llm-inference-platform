resource "google_compute_network" "llm_vpc" {
  name                    = "llm-platform-vpc"
  auto_create_subnetworks = false
  project                 = var.project_id
}

resource "google_compute_subnetwork" "cpu_subnet" {
  name          = "cpu-subnet"
  ip_cidr_range = "10.0.0.0/20"
  region        = var.region
  network       = google_compute_network.llm_vpc.id
  project       = var.project_id

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.4.0.0/14"
  }
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.8.0.0/20"
  }
}

resource "google_compute_subnetwork" "gpu_subnet" {
  name          = "gpu-subnet"
  ip_cidr_range = "10.1.0.0/20"
  region        = var.region
  network       = google_compute_network.llm_vpc.id
  project       = var.project_id
}

resource "google_compute_router" "router" {
  name    = "llm-router"
  region  = var.region
  network = google_compute_network.llm_vpc.id
  project = var.project_id
}

resource "google_compute_router_nat" "nat" {
  name                               = "llm-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  project                            = var.project_id
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}
