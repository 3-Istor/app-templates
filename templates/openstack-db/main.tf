# --- Génère des mots de passe si non fournis ---
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

# --- ÉTAPE 1 : Infra (crée les ports → on obtient les IPs) ---
# On passe un user_data temporaire vide, on le remplacera pas.
# mais besoin des IPs AVANT le cloud-init...
#
# Le module infra crée les ports d'abord.
# On appelle le module software APRÈS avec les IPs.
# Puis on passe le cloud-init au module infra.
# Terraform résout ça grâce au dependency graph.

module "infrastructure" {
  source = "../../modules/infra/openstack-db-cluster"

  app_name       = var.app_name
  project_name   = var.project_name
  flavor_name    = var.flavor_name
  image_name     = var.image_name
  instance_count = var.instance_count

  user_data_list = module.software.user_data_list
}

module "software" {
  source = "../../modules/software/db-postgres"

  app_name = var.app_name
  node_ips = module.infrastructure.db_ips

  db_name              = var.db_name
  db_user              = var.db_user
  db_password          = local.db_password
  replication_password = local.replication_password
  postgres_password    = local.postgres_password
}
