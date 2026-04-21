module "software" {
  source   = "../../modules/software/web-nginx"
  app_name = var.app_name
}

module "infrastructure" {
  source = "../../modules/infra/aws-asg-cluster"

  app_name           = var.app_name
  instance_count     = var.instance_count
  project_name       = var.project_name
  instance_type      = var.instance_type
  ami_id             = var.ami_id
  key_name           = var.key_name

  # Injection dynamique via les data sources
  private_subnet_ids = data.aws_subnets.private.ids
  app_sg_id          = data.aws_security_group.app_sg.id
  target_group_arn   = data.aws_lb_target_group.app_tg.arn

  user_data = module.software.user_data_rendered
}

# Output nettoyé et dynamique
output "public_url" {
  value       = "http://${data.aws_lb.main.dns_name}"
  description = "URL publique de l'Application Load Balancer"
}
