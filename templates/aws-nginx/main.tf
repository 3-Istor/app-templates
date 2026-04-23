module "software" {
  source   = "../../modules/software/web-nginx"
  app_name = var.app_name
}

module "infrastructure" {
  source = "../../modules/infra/aws-asg-cluster"

  app_name       = var.app_name
  instance_count = var.instance_count
  project_name   = var.project_name
  instance_type  = var.instance_type
  ami_id         = var.ami_id
  key_name       = var.key_name

  vpc_id             = data.terraform_remote_state.base_infra.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.base_infra.outputs.private_subnet_ids
  app_sg_id          = data.terraform_remote_state.base_infra.outputs.app_sg_id
  alb_listener_arn   = data.terraform_remote_state.base_infra.outputs.alb_listener_arn

  rule_priority = random_integer.rule_priority.result # TODO: Manage this using the CMP to avoid conflicts !

  user_data = module.software.user_data_rendered
}
