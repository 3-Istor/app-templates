output "db_primary_ip" {
  value = openstack_networking_port_v2.db_primary_port.all_fixed_ips[0]
}

output "db_replica_ip" {
  value = openstack_networking_port_v2.db_replica_port.all_fixed_ips[0]
}

output "db_lb_vip" {
  value = openstack_lb_loadbalancer_v2.db_lb.vip_address
}

output "db_public_ip" {
  value = openstack_networking_floatingip_v2.db_fip.address
}

output "db_connection_string" {
  value = "postgresql://${openstack_networking_floatingip_v2.db_fip.address}:5432"
}
