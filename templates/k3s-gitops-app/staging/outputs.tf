output "hostname" {
  description = "Public hostname of the staging environment. The CMP writes it to the registry record (apps[].hostnames.staging) and to deploy/env/staging/*.yaml."
  value       = local.hostname
}

output "vault_path" {
  description = "secrets.vaultPath of the staging values files"
  value       = "${local.mount}/${local.path}"
}

output "vault_role" {
  description = "secrets.vaultRole of the staging values files"
  value       = vault_kubernetes_auth_backend_role.staging_role.role_name
}

output "oidc_client_id" {
  description = "ingress.oidc.clientID of the staging values files"
  value       = keycloak_openid_client.staging_client.client_id
}
