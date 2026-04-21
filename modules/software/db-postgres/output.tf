output "user_data_db" {
  value = data.cloudinit_config.db_node[*].rendered
}

output "user_data_tiebreaker" {
  value = data.cloudinit_config.tiebreaker_node.rendered
}
