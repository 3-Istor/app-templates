data "openstack_networking_network_v2" "internal_net" {
  name = "${var.project_name}-internal-network"
}

data "openstack_networking_subnet_v2" "internal_subnet" {
  name = "${var.project_name}-internal-subnet"
}

data "openstack_networking_network_v2" "ext_net" {
  name = "${var.project_name}-external-network"
}

data "openstack_compute_keypair_v2" "kp_admin" {
  name = "${var.project_name}-kp-admin"
}

data "openstack_networking_secgroup_v2" "sg_base" {
  name = "${var.project_name}-default-sg"
}

data "openstack_networking_secgroup_v2" "db_sg" {
  name = "${var.project_name}-db-sg"
}
