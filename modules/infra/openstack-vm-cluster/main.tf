#################################### VMs ######################################

resource "openstack_compute_servergroup_v2" "app_anti_affinity" {
  name     = "${var.app_name}-anti-affinity"
  policies = ["anti-affinity"]
}

resource "openstack_compute_instance_v2" "app_nodes" {
  count       = var.instance_count
  name        = "${var.app_name}-node-${count.index + 1}"
  image_name  = var.image_name
  flavor_name = var.flavor_name
  key_pair    = data.openstack_compute_keypair_v2.kp_admin.name
  user_data   = var.user_data

  availability_zone = var.app_hosts[count.index % length(var.app_hosts)]

  security_groups = [
    data.openstack_networking_secgroup_v2.sg_base.name,
    data.openstack_networking_secgroup_v2.web_sg.name
  ]

  network {
    uuid = data.openstack_networking_network_v2.internal_net.id
  }

  scheduler_hints {
    group = openstack_compute_servergroup_v2.app_anti_affinity.id
  }
}

###############################################################################

########################## LOAD BALANCER (Octavia) ############################

resource "openstack_lb_loadbalancer_v2" "app_lb" {
  name           = "${var.app_name}-lb"
  vip_subnet_id  = data.openstack_networking_subnet_v2.internal_subnet.id
  admin_state_up = true
}

resource "openstack_lb_listener_v2" "app_listener" {
  name            = "${var.app_name}-listener-http"
  protocol        = "HTTP"
  protocol_port   = 80
  loadbalancer_id = openstack_lb_loadbalancer_v2.app_lb.id
}

resource "openstack_lb_pool_v2" "app_pool" {
  name        = "${var.app_name}-pool"
  protocol    = "HTTP"
  lb_method   = "ROUND_ROBIN"
  listener_id = openstack_lb_listener_v2.app_listener.id
}

resource "openstack_lb_monitor_v2" "app_monitor" {
  name           = "${var.app_name}-monitor"
  pool_id        = openstack_lb_pool_v2.app_pool.id
  type           = "HTTP"
  delay          = 10
  timeout        = 5
  max_retries    = 3
  url_path       = "/"
  expected_codes = "200"
}

resource "openstack_lb_member_v2" "app_members" {
  count         = var.instance_count
  pool_id       = openstack_lb_pool_v2.app_pool.id
  address       = openstack_compute_instance_v2.app_nodes[count.index].network.0.fixed_ip_v4
  protocol_port = 80
}

###############################################################################

################################ FLOATING IP ##################################

resource "openstack_networking_floatingip_v2" "lb_fip" {
  pool = data.openstack_networking_network_v2.ext_net.name
}

resource "openstack_networking_floatingip_associate_v2" "lb_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.lb_fip.address
  port_id     = openstack_lb_loadbalancer_v2.app_lb.vip_port_id
}

output "app_public_url" {
  value = "http://${openstack_networking_floatingip_v2.lb_fip.address}"
}

###############################################################################
