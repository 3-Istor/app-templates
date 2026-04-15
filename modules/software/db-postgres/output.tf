output "user_data_primary" {
  value       = data.cloudinit_config.db_primary.rendered
  description = "Cloud-init for primary DB node"
}

output "user_data_replica" {
  value       = data.cloudinit_config.db_replica.rendered
  description = "Cloud-init for replica DB node"
}
