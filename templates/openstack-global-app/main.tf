resource "random_password" "db_password" {
  length  = 16
  special = false
}
resource "random_password" "replication" {
  length  = 16
  special = false
}
resource "random_password" "postgres" {
  length  = 16
  special = false
}

locals {
  final_db_password = var.db_password != "" ? var.db_password : random_password.db_password.result
}

module "software_db" {
  source               = "../../modules/software/db-postgres"
  app_name             = var.app_name
  db_ips               = module.infra_db.db_ips
  tiebreaker_ip        = module.infra_db.tiebreaker_ip
  db_name              = var.db_name
  db_user              = var.db_user
  db_password          = local.final_db_password
  replication_password = random_password.replication.result
  postgres_password    = random_password.postgres.result
}

module "infra_db" {
  source                 = "../../modules/infra/openstack-db-cluster"
  app_name               = "${var.app_name}-db"
  project_name           = var.project_name
  flavor_name            = var.db_flavor_name
  tiebreaker_flavor_name = var.tiebreaker_flavor
  image_name             = var.db_image_name
  instance_count         = var.db_instance_count
  db_hosts               = var.db_hosts
  tiebreaker_host        = var.tiebreaker_host

  user_data_db         = module.software_db.user_data_db
  user_data_tiebreaker = module.software_db.user_data_tiebreaker
}

module "software_app" {
  source      = "../../modules/software/web-python-db"
  app_name    = var.app_name
  db_host     = module.infra_db.db_lb_vip
  db_name     = var.db_name
  db_user     = var.db_user
  db_password = local.final_db_password
}

module "infra_app" {
  source         = "../../modules/infra/openstack-vm-cluster"
  app_name       = "${var.app_name}-web"
  instance_count = var.app_instance_count
  project_name   = var.project_name
  flavor_name    = var.app_flavor_name
  image_name     = var.app_image_name
  app_hosts      = var.app_hosts

  user_data = module.software_app.user_data_rendered
}

output "app_public_url" {
  value = module.infra_app.app_public_url
}

output "db_public_ip" {
  value = module.infra_db.db_public_ip
}
