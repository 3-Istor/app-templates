variable "project_name" {
  type        = string
  description = "The name of the project (e.g., sandbox, alpha-team)"
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

variable "github_token" {
  type        = string
  sensitive   = true
  description = "GitHub Classic PAT or Installation Token used to write to the cnp-projects repository"
}

variable "discord_webhook_url" {
  type        = string
  description = "Discord Webhook URL"
}
