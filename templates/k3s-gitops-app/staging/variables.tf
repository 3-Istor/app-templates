variable "app_name" {
  type        = string
  description = "The app whose staging environment this is"
}

# ==============================================================================
# PROJECT & CORE VARIABLES
# ==============================================================================

variable "project_name" {
  type        = string
  description = "The name of the associated CNP Project (e.g., sandbox, production)"
}

variable "target_cloud" {
  type        = string
  description = "The cloud the project runs on. Comes from the project's registry record and selects the Vault auth mount, the storage class, and the state key prefix."
  default     = "onprem"

  validation {
    condition     = contains(["onprem", "aws", "gcp"], var.target_cloud)
    error_message = "target_cloud must be one of: onprem, aws, gcp. It must also match the name of a registered Argo CD cluster."
  }
}

variable "domain" {
  type        = string
  description = "Public DNS zone applications are exposed under"
  default     = "3istor.com"
}

# ==============================================================================
# KEYCLOAK PROVIDER VARIABLES
# ==============================================================================

variable "keycloak_realm" {
  type        = string
  description = "The platform Keycloak Realm"
  default     = "3istor"
}

variable "keycloak_realm_id" {
  type        = string
  description = "Realm the application's OIDC client is created in. Empty means the project's own realm, which is the current behaviour. Set explicitly once the project runs its own Keycloak IAMaaS (D-04)."
  default     = ""
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
