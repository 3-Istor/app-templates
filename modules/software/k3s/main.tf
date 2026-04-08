data "cloudinit_config" "k3s_config" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content      = <<-EOF
      #cloud-config
      package_update: true
      packages:
        - curl

      runcmd:
        # Install K3s server.
        # --tls-san ensures the Kube API certificate is valid for the Floating IP.
        # --write-kubeconfig-mode 644 allows standard users/Terraform to read the config.
        - curl -sfL https://get.k3s.io | sh -s - server --tls-san ${var.public_ip} --write-kubeconfig-mode 644
    EOF
  }
}

output "user_data_rendered" {
  value       = data.cloudinit_config.k3s_config.rendered
  description = "Cloud-init configuration string for K3s deployment"
}
