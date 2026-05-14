# Deny all external ingress (LB handles external traffic)
resource "google_compute_firewall" "deny_all_ingress" {
  name    = "deny-all-ingress"
  network = google_compute_network.llm_vpc.name
  priority = 1000

  deny { protocol = "all" }
  direction     = "INGRESS"
  source_ranges = ["0.0.0.0/0"]
}

# Allow internal cluster communication
resource "google_compute_firewall" "allow_internal" {
  name    = "allow-internal"
  network = google_compute_network.llm_vpc.name
  priority = 900

  allow { protocol = "tcp" }
  allow { protocol = "udp" }
  allow { protocol = "icmp" }
  direction     = "INGRESS"
  source_ranges = ["10.0.0.0/8"]
}

# Allow GKE master to nodes (required)
resource "google_compute_firewall" "allow_master_to_nodes" {
  name    = "allow-master-nodes"
  network = google_compute_network.llm_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["443", "10250", "8443"]
  }
  direction     = "INGRESS"
  source_ranges = ["172.16.0.0/28"]  # Update to your master CIDR
}