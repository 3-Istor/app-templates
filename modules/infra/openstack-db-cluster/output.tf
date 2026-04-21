output "db_ips" {
  value = openstack_networking_port_v2.db_ports[*].all_fixed_ips[0]
}

output "db_lb_vip" {
  value = openstack_networking_port_v2.db_lb_port.all_fixed_ips[0]
}

output "db_public_ip" {
  value = openstack_networking_floatingip_v2.db_fip.address
}

output "db_connection_string" {
  value = "postgresql://${openstack_networking_floatingip_v2.db_fip.address}:5000"
}

output "tiebreaker_ip" {
  value = openstack_networking_port_v2.tiebreaker_port.all_fixed_ips[0]
}
