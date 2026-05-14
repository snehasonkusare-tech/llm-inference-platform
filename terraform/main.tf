provider "google" {
  project = var.project_id
  region  = var.region
}

module "networking" {
  source     = "./modules/networking"
  region     = var.region
  project_id = var.project_id
}

module "iam" {
  source     = "./modules/iam"
  project_id = var.project_id
}

module "gke" {
  source           = "./modules/gke"
  region           = var.region
  project_id       = var.project_id
  network_id       = module.networking.vpc_id
  cpu_subnet_id    = module.networking.cpu_subnet_id
  gke_sa_email     = module.iam.gke_sa_email
  environment      = var.environment
  cpu_machine_type = var.cpu_machine_type
  gpu_machine_type = var.gpu_machine_type
}

module "storage" {
  source     = "./modules/storage"
  region     = var.region
  project_id = var.project_id
}

module "registry" {
  source     = "./modules/registry"
  region     = var.region
  project_id = var.project_id
}

module "secrets" {
  source     = "./modules/secrets"
  region     = var.region
  project_id = var.project_id
}
