variable "app_name"       { type = string }
variable "instance_count" { type = number }
variable "project_name"   { type = string }
variable "instance_type"  { type = string }
variable "ami_id"         { type = string }
variable "user_data"      { type = string }

# Récupérés depuis le terraform-aws existant
variable "private_subnet_ids" { type = list(string) }
variable "app_sg_id"          { type = string }
variable "target_group_arn"   { type = string }
variable "key_name"           { type = string }
