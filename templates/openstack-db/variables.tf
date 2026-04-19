variable "app_name" {
  type        = string
  description = "Application name"
  default     = "test-db"
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

variable "db_name" {
  type    = string
  default = "app-db"
}

variable "db_user" {
  type    = string
  default = "app-user"
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "instance_count" {
  type    = number
  default = 3
}
