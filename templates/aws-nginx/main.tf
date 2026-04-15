# ── Software : cloud-init Nginx (module réutilisé tel quel) ───────────────────
module "software" {
  source   = "../../modules/software/web-nginx"
  app_name = var.app_name
}

# ── Infrastructure : ASG AWS ──────────────────────────────────────────────────
module "infrastructure" {
  source = "../../modules/infra/aws-asg-cluster"

  app_name           = var.app_name
  instance_count     = var.instance_count
  project_name       = var.project_name
  instance_type      = var.instance_type
  ami_id             = var.ami_id
  key_name           = var.key_name
  private_subnet_ids = var.private_subnet_ids
  app_sg_id          = var.app_sg_id
  target_group_arn   = var.target_group_arn

  # user_data est déjà encodé base64+gzip par le module software (cloudinit_config)
  user_data = module.software.user_data_rendered
}

output "public_url" {
  value = module.infrastructure.app_public_url
}
