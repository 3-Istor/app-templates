variable "github_token" {
  type        = string
  sensitive   = true
  description = "Installation access token from GitHub App (Used for repo creation)"
}

variable "github_owner" {
  type        = string
  description = "The GitHub User or Organization where the repo will be created"
}

variable "template_repo_name" {
  type        = string
  description = "Name of the template repository"
}

variable "app_name" {
  type        = string
  description = "The name of the application"
}

variable "project_name" {
  type        = string
  description = "The name of the CNP project"
}

variable "app_type" {
  type        = string
  description = "Type of app: 'static' or 'fullstack'"
  default     = "static"
}

# --- Keycloak Variables ---
variable "keycloak_realm" {
  type        = string
  description = "The Keycloak Realm name"
  default     = "3istor"
}

# --- Vault Variables ---
variable "vault_url" {
  type    = string
  default = "https://vault.3istor.com"
}

variable "vault_token" {
  type      = string
  sensitive = true
}

# --- Registry Auth Variables (Classic PAT) ---
variable "github_registry_username" {
  type        = string
  description = "The GitHub username used to pull private images"
  default     = "3-Istor"
}

variable "github_registry_token" {
  type        = string
  sensitive   = true
  description = "Classic Personal Access Token (PAT) with strictly 'read:packages' scope"
}
