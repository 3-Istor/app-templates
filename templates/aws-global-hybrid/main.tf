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

# ==========================================
# OPENSTACK : DATABASE CLUSTER
# ==========================================
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

# ==========================================
# AWS : APP CLUSTER (FASTAPI)
# ==========================================
module "software_app" {
  source       = "../../modules/software/web-fastapi-git"
  app_name     = var.app_name
  git_repo_url = var.git_repo_url
  git_branch   = var.git_branch

  # Inject the OpenStack LoadBalancer VIP via the VPN tunnel
  db_host     = module.infra_db.db_lb_vip
  db_name     = var.db_name
  db_user     = var.db_user
  db_password = local.final_db_password
}

module "infra_app" {
  source         = "../../modules/infra/aws-asg-cluster"
  app_name       = var.app_name
  instance_count = var.app_instance_count
  project_name   = var.project_name
  instance_type  = var.app_instance_type
  ami_id         = data.aws_ami.ubuntu_2404.id
  key_name       = var.aws_key_name

  vpc_id             = data.terraform_remote_state.base_infra.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.base_infra.outputs.private_subnet_ids
  app_sg_id          = data.terraform_remote_state.base_infra.outputs.app_sg_id
  alb_listener_arn   = data.terraform_remote_state.base_infra.outputs.alb_listener_arn

  rule_priority = random_integer.rule_priority.result # TODO: Manage this using the CMP to avoid conflicts !

  user_data = module.software_app.user_data_rendered
}

# ==========================================
# CLOUDFLARE DNS
# ==========================================
resource "cloudflare_record" "app_cname" {
  zone_id = var.cloudflare_zone_id
  name    = var.app_name
  content = data.terraform_remote_state.base_infra.outputs.alb_dns_name
  type    = "CNAME"
  proxied = true
}
