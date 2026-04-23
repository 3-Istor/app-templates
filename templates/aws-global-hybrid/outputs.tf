output "app_url" {
  value       = "https://${var.app_name}.3istor.com"
  description = "Public URL of the FastAPI application"
}

output "db_internal_vip" {
  value       = module.infra_db.db_lb_vip
  description = "Internal OpenStack VIP (accessible via VPN from AWS)"
}

output "db_public_ip" {
  value       = module.infra_db.db_public_ip
  description = "Public Floating IP for direct DB admin access"
}
