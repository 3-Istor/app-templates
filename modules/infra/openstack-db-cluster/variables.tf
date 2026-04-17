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

variable "user_data_primary" {
  type        = string
  description = "cloud-init user data for primary DB"
}

variable "user_data_replica" {
  description = "cloud-init user data for DB replica"
  type        = string
  default     = ""
}
