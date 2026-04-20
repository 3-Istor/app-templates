variable "app_name" {
  type = string
}

variable "project_name" {
  type = string
}

variable "flavor_name" {
  type = string
}

variable "tiebreaker_flavor_name" {
  type = string
}

variable "image_name" {
  type = string
}

variable "instance_count" {
  type    = number
  default = 2
}

variable "user_data_db" {
  type = list(string)
}

variable "user_data_tiebreaker" {
  type = string
}

variable "db_hosts" {
  type    = list(string)
  default = ["nova:pae-node-2", "nova:pae-node-3"]
}

variable "tiebreaker_host" {
  type    = string
  default = "nova:pae-node-2"
}
