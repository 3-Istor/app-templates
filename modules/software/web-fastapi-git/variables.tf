variable "app_name" {
  type = string
}

variable "git_repo_url" {
  type = string
}

variable "git_branch" {
  type    = string
  default = "main"
}

variable "db_host" {
  type = string
}

variable "db_port" {
  type    = number
  default = 5000
}

variable "db_name" {
  type = string
}

variable "db_user" {
  type = string
}

variable "db_password" {
  type = string
}
