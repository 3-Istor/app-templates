variable "project_name" {
  type        = string
  description = "The name of the associated CNP Project (e.g., sandbox, production)"
}

variable "keycloak_realm" {
  type        = string
  description = "The platform Keycloak Realm"
  default     = "3istor"
}

variable "keycloak_url" {
  type        = string
  description = "The URL of the Keycloak server"
  default     = "https://admin-auth.3istor.com"
}

variable "keycloak_admin_username" {
  type        = string
  description = "Keycloak admin CLI username"
  default     = "admin"
}

variable "keycloak_admin_password" {
  type        = string
  sensitive   = true
  description = "Keycloak admin CLI password"
  default     = ""
}

variable "keycloak_client_id" {
  type        = string
  description = "Master realm client of the provisioner (client credentials, e.g. cmp-provisioner), used when keycloak_client_secret is set"
  default     = ""
}

variable "keycloak_client_secret" {
  type        = string
  sensitive   = true
  description = "Secret of keycloak_client_id; empty falls back to the admin user"
  default     = ""
}

variable "vault_url" {
  type        = string
  description = "The address of the Vault server"
  default     = "https://vault.3istor.com"
}

variable "vault_token" {
  type        = string
  sensitive   = true
  description = "The token used to authenticate with Vault"
}
