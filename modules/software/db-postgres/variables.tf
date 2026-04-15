variable "app_name" { type = string }

variable "primary_ip" { type = string }
variable "replica_ip" { type = string }

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

variable "replication_password" {
  type      = string
  sensitive = true
}

variable "postgres_password" {
  type      = string
  sensitive = true
}
