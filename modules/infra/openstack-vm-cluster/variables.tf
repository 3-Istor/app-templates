variable "app_name" { type = string }
variable "instance_count" { type = number }
variable "project_name" { type = string }
variable "flavor_name" { type = string }
variable "image_name" { type = string }
variable "user_data" { type = string }

variable "app_hosts" {
  type    = list(string)
  default = ["nova:pae-node-2", "nova:pae-node-3"]
}
