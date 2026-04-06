variable "app_name" {
  type = string
}

variable "git_repo_url" {
  type        = string
  description = "The HTTP/HTTPS URL of the Git repository"
}

variable "git_branch" {
  type        = string
  description = "The branch to deploy"
  default     = "main"
}
