data "openstack_networking_network_v2" "internal_net" {
  name = "${var.project_name}-internal-net"
}

data "openstack_networking_subnet_v2" "internal_subnet" {
  name = "${var.project_name}-internal-subnet"
}

data "openstack_networking_network_v2" "ext_net" {
  name = "ext-net"
}

data "openstack_compute_keypair_v2" "kp_admin" {
  name = "${var.project_name}-kp-admin"
}

data "openstack_networking_secgroup_v2" "sg_base" {
  name = "sg-base"
}

data "openstack_networking_secgroup_v2" "web_sg" {
  name = "sg-web"
}

data "openstack_networking_secgroup_v2" "db_sg" {
  name = "sg-db"
}
