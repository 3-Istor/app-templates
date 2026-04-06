module "software" {
  source       = "../../modules/software/web-git"
  app_name     = var.app_name
  git_repo_url = var.git_repo_url
  git_branch   = var.git_branch
}

module "infrastructure" {
  source = "../../modules/infra/openstack-vm-cluster"

  app_name       = var.app_name
  instance_count = var.instance_count
  project_name   = var.project_name
  flavor_name    = var.flavor_name
  image_name     = var.image_name

  user_data = module.software.user_data_rendered
}

output "public_url" {
  value = module.infrastructure.app_public_url
}
