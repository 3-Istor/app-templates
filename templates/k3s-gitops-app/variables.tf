# ==============================================================================
# GITHUB PROVIDER VARIABLES
# ==============================================================================

variable "github_token" {
  type        = string
  sensitive   = true
  description = "Dynamic Installation Access Token from the GitHub App"
}

variable "github_owner" {
  type        = string
  description = "The GitHub organization or username where the repository will be created"
}

variable "template_repo_name" {
  type        = string
  description = "The name of the source template repository on GitHub"
}

variable "app_name" {
  type        = string
  description = "The name of the new application to create"
}

variable "app_type" {
  type        = string
  description = "The application architecture type (static or fullstack)"
  default     = "static"
}

# ==============================================================================
# PROJECT & CORE VARIABLES
# ==============================================================================

variable "project_name" {
  type        = string
  description = "The name of the associated CNP Project (e.g., sandbox, production)"
}

# ==============================================================================
# KEYCLOAK PROVIDER VARIABLES
# ==============================================================================

variable "keycloak_realm" {
  type        = string
  description = "The target Keycloak Realm"
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
}

# ==============================================================================
# VAULT PROVIDER VARIABLES
# ==============================================================================

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

# ==============================================================================
# REGISTRY IMAGE PULL VARIABLES (Classic PAT)
# ==============================================================================

variable "github_registry_username" {
  type        = string
  description = "The GitHub username used to pull images from ghcr.io"
  default     = "3-Istor"
}

variable "github_registry_token" {
  type        = string
  sensitive   = true
  description = "The Classic GitHub PAT with strictly 'read:packages' permission"
}

# ==============================================================================
# ADDED: CLOUDFLARE PROVIDER VARIABLES
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
