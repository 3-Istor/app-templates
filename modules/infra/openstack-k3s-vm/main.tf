data "openstack_networking_network_v2" "internal_net" {
  name = "${var.project_name}-internal-net"
}

data "openstack_compute_keypair_v2" "kp_admin" {
  name = "${var.project_name}-kp-admin"
}

data "openstack_networking_secgroup_v2" "sg_base" {
  name = "sg-base"
}

data "openstack_networking_secgroup_v2" "sg_web" {
  name = "sg-web"
}

data "openstack_networking_secgroup_v2" "sg_k3s" {
  name = "sg-k3s"
}

resource "openstack_compute_instance_v2" "k3s_node" {
  name        = "${var.app_name}-node"
  image_name  = var.image_name
  flavor_name = var.flavor_name
  key_pair    = data.openstack_compute_keypair_v2.kp_admin.name
  user_data   = var.user_data

  security_groups = [
    data.openstack_networking_secgroup_v2.sg_base.name,
    data.openstack_networking_secgroup_v2.sg_web.name,
    data.openstack_networking_secgroup_v2.sg_k3s.name
  ]

  network {
    uuid = data.openstack_networking_network_v2.internal_net.id
  }
}

data "openstack_networking_port_v2" "k3s_port" {
  device_id = openstack_compute_instance_v2.k3s_node.id
}

resource "openstack_networking_floatingip_associate_v2" "k3s_fip_assoc" {
  floating_ip = var.public_ip
  port_id     = data.openstack_networking_port_v2.k3s_port.id
}
