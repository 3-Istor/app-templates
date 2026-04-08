data "openstack_networking_network_v2" "ext_net" {
  name = "ext-net"
}

resource "openstack_networking_floatingip_v2" "k3s_fip" {
  pool = data.openstack_networking_network_v2.ext_net.name
}

module "software" {
  source    = "../../modules/software/k3s"
  public_ip = openstack_networking_floatingip_v2.k3s_fip.address
}

module "infrastructure" {
  source = "../../modules/infra/openstack-k3s-vm"

  app_name     = var.app_name
  project_name = var.project_name
  flavor_name  = var.flavor_name
  image_name   = var.image_name

  public_ip = openstack_networking_floatingip_v2.k3s_fip.address
  user_data = module.software.user_data_rendered
}

output "k3s_public_ip" {
  value = openstack_networking_floatingip_v2.k3s_fip.address
}

output "kubeconfig_fetch_command" {
  value       = "ssh ubuntu@${openstack_networking_floatingip_v2.k3s_fip.address} 'cat /etc/rancher/k3s/k3s.yaml' > kubeconfig.yaml && sed -i 's/127.0.0.1/${openstack_networking_floatingip_v2.k3s_fip.address}/g' kubeconfig.yaml"
  description = "Run this command to download the kubeconfig and point it to the public IP."
}
