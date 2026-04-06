variable "app_name" {
  type    = string
  default = "git-app"
}

variable "instance_count" {
  type    = number
  default = 2
}

variable "project_name" {
  type    = string
  default = "3-istor-cloud"
}

variable "flavor_name" {
  type    = string
  default = "m1.small"
}

variable "image_name" {
  type    = string
  default = "ubuntu-24.04-2026"
}

variable "git_repo_url" {
  type        = string
  description = "The HTTP/HTTPS URL of the Git repository"
}

variable "git_branch" {
  type    = string
  default = "main"
}
