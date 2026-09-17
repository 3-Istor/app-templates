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
