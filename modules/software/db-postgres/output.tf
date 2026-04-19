output "user_data_list" {
  value       = data.cloudinit_config.db_node[*].rendered
  description = "Liste des configurations Cloud-init pour chaque nœud DB"
}
