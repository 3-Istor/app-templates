#################################### VMs ######################################

resource "openstack_compute_servergroup_v2" "db_anti_affinity" {
  name     = "${var.app_name}-db-anti-affinity"
  policies = ["anti-affinity"]
}

resource "openstack_networking_port_v2" "db_primary_port" {
  name       = "${var.app_name}-db-primary-port"
  network_id = data.openstack_networking_network_v2.internal_net.id

  security_group_ids = [
    data.openstack_networking_secgroup_v2.sg_base.id,
    data.openstack_networking_secgroup_v2.db_sg.id,
  ]

  fixed_ip {
    subnet_id = data.openstack_networking_subnet_v2.internal_subnet.id
  }
}

resource "openstack_networking_port_v2" "db_replica_port" {
  name       = "${var.app_name}-db-replica-port"
  network_id = data.openstack_networking_network_v2.internal_net.id

  security_group_ids = [
    data.openstack_networking_secgroup_v2.sg_base.id,
    data.openstack_networking_secgroup_v2.db_sg.id,
  ]

  fixed_ip {
    subnet_id = data.openstack_networking_subnet_v2.internal_subnet.id
  }
}

# --- VMs ---

resource "openstack_compute_instance_v2" "db_primary" {
  name        = "${var.app_name}-db-primary"
  image_name  = var.image_name
  flavor_name = var.flavor_name
  key_pair    = data.openstack_compute_keypair_v2.kp_admin.name
  user_data   = var.user_data_primary

  network {
    port = openstack_networking_port_v2.db_primary_port.id
  }

  # scheduler_hints {
  #   group = openstack_compute_servergroup_v2.db_anti_affinity.id
  # }
}

resource "openstack_compute_instance_v2" "db_replica" {
  name        = "${var.app_name}-db-replica"
  image_name  = var.image_name
  flavor_name = var.flavor_name
  key_pair    = data.openstack_compute_keypair_v2.kp_admin.name
  user_data   = var.user_data_replica

  network {
    port = openstack_networking_port_v2.db_replica_port.id
  }

  # scheduler_hints {
  #   group = openstack_compute_servergroup_v2.db_anti_affinity.id
  # }
}

###############################################################################

########################## LOAD BALANCER (Octavia) ############################

resource "openstack_lb_loadbalancer_v2" "db_lb" {
  name           = "${var.app_name}-db-lb"
  vip_subnet_id  = data.openstack_networking_subnet_v2.internal_subnet.id
  admin_state_up = true
}

# =======================================================================
# 1. POOL READ/WRITE (Master) - Port 5000
# =======================================================================
resource "openstack_lb_listener_v2" "db_rw_listener" {
  name            = "${var.app_name}-db-listener-rw"
  protocol        = "TCP"
  protocol_port   = 5000
  loadbalancer_id = openstack_lb_loadbalancer_v2.db_lb.id
}

resource "openstack_lb_pool_v2" "db_rw_pool" {
  name        = "${var.app_name}-db-rw-pool"
  protocol    = "TCP"
  lb_method   = "ROUND_ROBIN"
  listener_id = openstack_lb_listener_v2.db_rw_listener.id
}

# Health check via Patroni REST API (HTTP 200 on /primary)
resource "openstack_lb_monitor_v2" "db_rw_monitor" {
  name           = "${var.app_name}-db-rw-monitor"
  pool_id        = openstack_lb_pool_v2.db_rw_pool.id
  type           = "HTTP"
  delay          = 10
  timeout        = 5
  max_retries    = 3
  url_path       = "/primary"
  expected_codes = "200"
}

# We add BOTH VMs to the pool. Octavia will only send traffic to the one passing the /primary check.
resource "openstack_lb_member_v2" "db_primary_member_rw" {
  pool_id       = openstack_lb_pool_v2.db_rw_pool.id
  address       = openstack_networking_port_v2.db_primary_port.all_fixed_ips[0]
  protocol_port = 5432 # Traffic goes to Postgres
  monitor_port  = 8008 # Health check goes to Patroni
}

resource "openstack_lb_member_v2" "db_replica_member_rw" {
  pool_id       = openstack_lb_pool_v2.db_rw_pool.id
  address       = openstack_networking_port_v2.db_replica_port.all_fixed_ips[0]
  protocol_port = 5432
  monitor_port  = 8008
}

# =======================================================================
# 2. POOL READ-ONLY (Replica) - Port 5001
# =======================================================================
resource "openstack_lb_listener_v2" "db_ro_listener" {
  name            = "${var.app_name}-db-listener-ro"
  protocol        = "TCP"
  protocol_port   = 5001
  loadbalancer_id = openstack_lb_loadbalancer_v2.db_lb.id
}

resource "openstack_lb_pool_v2" "db_ro_pool" {
  name        = "${var.app_name}-db-ro-pool"
  protocol    = "TCP"
  lb_method   = "ROUND_ROBIN"
  listener_id = openstack_lb_listener_v2.db_ro_listener.id
}

# Health check via Patroni REST API (HTTP 200 on /replica)
resource "openstack_lb_monitor_v2" "db_ro_monitor" {
  name           = "${var.app_name}-db-ro-monitor"
  pool_id        = openstack_lb_pool_v2.db_ro_pool.id
  type           = "HTTP"
  delay          = 10
  timeout        = 5
  max_retries    = 3
  url_path       = "/replica"
  expected_codes = "200"
}

# We add BOTH VMs to the pool. Octavia will only send traffic to the one passing the /replica check.
resource "openstack_lb_member_v2" "db_primary_member_ro" {
  pool_id       = openstack_lb_pool_v2.db_ro_pool.id
  address       = openstack_networking_port_v2.db_primary_port.all_fixed_ips[0]
  protocol_port = 5432
  monitor_port  = 8008
}

resource "openstack_lb_member_v2" "db_replica_member_ro" {
  pool_id       = openstack_lb_pool_v2.db_ro_pool.id
  address       = openstack_networking_port_v2.db_replica_port.all_fixed_ips[0]
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
