variable "app_name" {
  type    = string
  default = "global-demo"
}

variable "project_name" {
  type    = string
  default = "3-istor-cloud"
}

variable "app_instance_count" {
  type    = number
  default = 2
}

variable "app_flavor_name" {
  type    = string
  default = "m1.small"
}

variable "app_image_name" {
  type    = string
  default = "ubuntu-24.04-2026"
}

variable "db_instance_count" {
  type    = number
  default = 2
}

variable "db_flavor_name" {
  type    = string
  default = "m1.small"
}

variable "db_image_name" {
  type    = string
  default = "ubuntu-24.04-2026"
}

variable "tiebreaker_flavor" {
  type    = string
  default = "m1.nano"
}

variable "db_name" {
  type    = string
  default = "demodb"
}

variable "db_user" {
  type    = string
  default = "demouser"
}

variable "db_password" {
  type    = string
  default = ""
}

variable "db_hosts" {
  type    = list(string)
  default = ["nova:pae-node-2", "nova:pae-node-3"]
}

variable "tiebreaker_host" {
  type    = string
  default = "nova:pae-node-2"
}

variable "app_hosts" {
  type    = list(string)
  default = ["nova:pae-node-2", "nova:pae-node-3"]
}
