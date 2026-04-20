resource "random_password" "replication" {
  length  = 24
  special = false
}

resource "random_password" "postgres" {
  length  = 24
  special = false
}

resource "random_password" "db_password" {
  count   = var.db_password == "" ? 1 : 0
  length  = 24
  special = false
}

locals {
  db_password          = var.db_password != "" ? var.db_password : random_password.db_password[0].result
  replication_password = random_password.replication.result
  postgres_password    = random_password.postgres.result
}

module "infrastructure" {
  source = "../../modules/infra/openstack-db-cluster"

  app_name               = var.app_name
  project_name           = var.project_name
  flavor_name            = var.flavor_name
  tiebreaker_flavor_name = var.tiebreaker_flavor_name
  image_name             = var.image_name
  instance_count         = 2

  db_hosts        = var.db_hosts
  tiebreaker_host = var.tiebreaker_host

  user_data_db         = module.software.user_data_db
  user_data_tiebreaker = module.software.user_data_tiebreaker
}

module "software" {
  source = "../../modules/software/db-postgres"

  app_name      = var.app_name
  db_ips        = module.infrastructure.db_ips
  tiebreaker_ip = module.infrastructure.tiebreaker_ip

  db_name              = var.db_name
  db_user              = var.db_user
  db_password          = local.db_password
  replication_password = local.replication_password
  postgres_password    = local.postgres_password
}
