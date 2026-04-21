#################################### VMs ######################################

resource "openstack_networking_port_v2" "db_ports" {
  count      = var.instance_count
  name       = "${var.app_name}-db-port-${count.index + 1}"
  network_id = data.openstack_networking_network_v2.internal_net.id
  security_group_ids = [
    data.openstack_networking_secgroup_v2.sg_base.id,
    data.openstack_networking_secgroup_v2.db_sg.id,
  ]
  fixed_ip { subnet_id = data.openstack_networking_subnet_v2.internal_subnet.id }
}

resource "openstack_compute_instance_v2" "db_nodes" {
  count       = var.instance_count
  name        = "${var.app_name}-db-node-${count.index + 1}"
  image_name  = var.image_name
  flavor_name = var.flavor_name
  key_pair    = data.openstack_compute_keypair_v2.kp_admin.name
  user_data   = var.user_data_db[count.index]

  availability_zone = var.db_hosts[count.index]

  network { port = openstack_networking_port_v2.db_ports[count.index].id }
}

resource "openstack_networking_port_v2" "tiebreaker_port" {
  name       = "${var.app_name}-tiebreaker-port"
  network_id = data.openstack_networking_network_v2.internal_net.id
  security_group_ids = [
    data.openstack_networking_secgroup_v2.sg_base.id,
    data.openstack_networking_secgroup_v2.db_sg.id,
  ]
  fixed_ip { subnet_id = data.openstack_networking_subnet_v2.internal_subnet.id }
}

resource "openstack_compute_instance_v2" "tiebreaker_node" {
  name        = "${var.app_name}-tiebreaker"
  image_name  = var.image_name
  flavor_name = var.tiebreaker_flavor_name
  key_pair    = data.openstack_compute_keypair_v2.kp_admin.name
  user_data   = var.user_data_tiebreaker

  availability_zone = var.tiebreaker_host

  network { port = openstack_networking_port_v2.tiebreaker_port.id }
}

###############################################################################

########################## LOAD BALANCER (Octavia) ############################

resource "openstack_lb_loadbalancer_v2" "db_lb" {
  name           = "${var.app_name}-db-lb"
  vip_subnet_id  = data.openstack_networking_subnet_v2.internal_subnet.id
  admin_state_up = true

  security_group_ids = [
    data.openstack_networking_secgroup_v2.sg_base.id,
    data.openstack_networking_secgroup_v2.db_sg.id
  ]
}

resource "openstack_lb_listener_v2" "db_listener_rw" {
  name            = "${var.app_name}-listener-rw"
  protocol        = "TCP"
  protocol_port   = 5000
  loadbalancer_id = openstack_lb_loadbalancer_v2.db_lb.id
}

resource "openstack_lb_pool_v2" "db_pool_rw" {
  name        = "${var.app_name}-pool-rw"
  protocol    = "TCP"
  lb_method   = "ROUND_ROBIN"
  listener_id = openstack_lb_listener_v2.db_listener_rw.id
}

resource "openstack_lb_monitor_v2" "db_monitor_rw" {
  name           = "${var.app_name}-monitor-rw"
  pool_id        = openstack_lb_pool_v2.db_pool_rw.id
  type           = "HTTP"
  delay          = 10
  timeout        = 5
  max_retries    = 3
  url_path       = "/primary"
  expected_codes = "200"
}

resource "openstack_lb_member_v2" "db_members_rw" {
  count         = var.instance_count
  pool_id       = openstack_lb_pool_v2.db_pool_rw.id
  address       = openstack_networking_port_v2.db_ports[count.index].all_fixed_ips[0]
  protocol_port = 5432
  monitor_port  = 8008
}

###############################################################################

################################ FLOATING IP ##################################
resource "openstack_networking_floatingip_v2" "db_fip" {
  pool = data.openstack_networking_network_v2.ext_net.name
}

resource "openstack_networking_floatingip_associate_v2" "db_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.db_fip.address
  port_id     = openstack_lb_loadbalancer_v2.db_lb.vip_port_id
}

###############################################################################
