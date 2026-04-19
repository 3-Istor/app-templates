variable "app_name" {
  type        = string
  description = "Application name"
  default     = "test-db"
}

variable "project_name" {
  type        = string
  description = "Project name"
}

variable "flavor_name" {
  type        = string
  description = "Instance flavor name"
}

variable "image_name" {
  type        = string
  description = "Instance image name"
}

variable "instance_count" {
  type    = number
  default = 3
}

variable "user_data_list" {
  type = list(string)
}
