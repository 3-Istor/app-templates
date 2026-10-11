output "app_url" {
  description = "Public URL of the deployed application"
  value       = "https://${local.hostname}"
}

output "hostname" {
  description = "Public hostname. CMP adds this to the project's registry record, which is what puts it in the connector's routing table and the blackbox probe target list."
  value       = local.hostname
}

output "components" {
  description = "Application components Argo CD generates an Application for"
  value       = local.components
}

output "app_type" {
  description = "fullstack or static — decides the component split and the values file layout"
  value       = local.app_type
}

output "github_repo_url" {
  description = "Original source URL for imports; generated repository URL for catalog apps."
  value       = local.create_repository ? github_repository.app[0].html_url : var.existing_repository_url
}
