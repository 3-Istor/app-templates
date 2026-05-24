variable "github_token" {
  type        = string
  sensitive   = true
  description = "Installation access token from GitHub App"
}

variable "github_owner" {
  type        = string
  description = "The GitHub User or Organization where the repo will be created"
}

variable "template_repo_name" {
  type        = string
  description = "Name of the template repo (e.g. template-app-webapp-python-fastapi-react)"
}

variable "app_name" {
  type        = string
  description = "The name of the application"
}

variable "project_name" {
  type        = string
  description = "The name of the CNP project (Keycloak boundary)"
}

variable "vault_url" {
  type    = string
  default = "https://vault.3istor.com"
}

variable "vault_token" {
  type      = string
  sensitive = true
}

variable "app_type" {
  type        = string
  description = "Type of app: 'static' or 'fullstack'"
  default     = "static"
}
