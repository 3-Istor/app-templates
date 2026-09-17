variable "project_name" {
  type        = string
  description = "The name of the project (e.g., sandbox, alpha-team)"
}

variable "target_cloud" {
  type        = string
  description = "The cloud this project runs on. Selects the Vault auth mount and the state key prefix; the placement itself is expressed in the project's registry record."
  default     = "onprem"

  validation {
    condition     = contains(["onprem", "aws", "gcp"], var.target_cloud)
    error_message = "target_cloud must be one of: onprem, aws, gcp. It must also match the name of a registered Argo CD cluster."
  }
}

variable "domain" {
  type        = string
  description = "Public DNS zone the project's hostnames live under"
  default     = "3istor.com"
}

variable "project_description" {
  type        = string
  description = "A human-readable description of the project"
  default     = "Managed by CNP Platform"
}

variable "keycloak_url" {
  type    = string
  default = "https://admin-auth.3istor.com"
}

variable "keycloak_admin_username" {
  type    = string
  default = "admin"
}

variable "keycloak_admin_password" {
  type      = string
  sensitive = true
}

variable "keycloak_realm" {
  type    = string
  default = "3istor"
}

variable "vault_url" {
  type    = string
  default = "https://vault.3istor.com"
}

variable "vault_token" {
  type      = string
  sensitive = true
}

variable "discord_webhook_url" {
  type        = string
  description = "Discord Webhook URL"
}

# ==============================================================================
# CLOUDFLARE PROVIDER VARIABLES
# ==============================================================================

variable "cloudflare_api_token" {
  type        = string
  sensitive   = true
  description = "Cloudflare API Token with DNS & Zero Trust permissions"
}

variable "cloudflare_account_id" {
  type        = string
  description = "Your Cloudflare Account ID (Found in your Cloudflare Dashboard)"
}

variable "cloudflare_zone_id" {
  type        = string
  description = "The Cloudflare Zone ID of your domain (e.g., 3istor.com)"
}

# ==============================================================================
# GRAFANA PROVIDER VARIABLES
# ==============================================================================
variable "grafana_admin_password" {
  type        = string
  sensitive   = true
  description = "Admin password for Grafana"
}
