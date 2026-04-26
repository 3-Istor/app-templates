variable "app_name" {
  type    = string
  default = "hybrid-demo"
}

variable "project_name" {
  type    = string
  default = "3-istor-cloud"
}

# --- AWS (APP) ---
variable "aws_region" {
  type    = string
  default = "eu-west-3"
}

variable "app_instance_count" {
  type    = number
  default = 2
}

variable "app_instance_type" {
  type    = string
  default = "t3.micro"
}

variable "aws_key_name" {
  type        = string
  description = "Key pair in AWS"
  default     = "arcl"
}

variable "rule_priority" {
  type    = number
  default = 200
}

# --- OPENSTACK (DB) ---
variable "db_instance_count" {
  type    = number
  default = 2
}

variable "db_flavor_name" {
  type    = string
  default = "m1.small"
}

variable "tiebreaker_flavor" {
  type    = string
  default = "m1.small"
}

variable "db_image_name" {
  type    = string
  default = "ubuntu-24.04-2026"
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

# --- APP SOFTWARE (Git) ---
variable "git_repo_url" {
  type        = string
  description = "URL of your FastAPI repo"
}

variable "git_branch" {
  type    = string
  default = "main"
}

# --- CLOUDFLARE ---
variable "cloudflare_api_token" {
  type      = string
  sensitive = true
}

variable "cloudflare_zone_id" {
  type = string
}
