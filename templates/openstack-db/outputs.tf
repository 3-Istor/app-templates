# --- Outputs ---
output "db_connection_string" {
  value     = "postgresql://${var.db_user}:${local.db_password}@${module.infrastructure.db_public_ip}:5000/${var.db_name}"
  sensitive = true
}

output "db_public_ip" {
  value = module.infrastructure.db_public_ip
}

output "db_lb_vip" {
  value = module.infrastructure.db_lb_vip
}
