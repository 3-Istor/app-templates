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
  type = string
}

variable "keycloak_admin_username" {
  type = string
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
  type = string
}

variable "vault_token" {
  type      = string
  sensitive = true
}
