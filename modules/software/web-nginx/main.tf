################################# Cloud Init ##################################
data "cloudinit_config" "web_config" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content      = <<-EOF
      #cloud-config
      package_update: true
      packages:
        - nginx

      write_files:
        - path: /var/www/html/index.html
          content: |
            <h1>Welcome to ${var.app_name}</h1>
            <p>IP: $(hostname -I)</p>

      runcmd:
        - systemctl enable nginx
        - systemctl restart nginx
    EOF
  }
}

###############################################################################

output "user_data_rendered" {
  value       = data.cloudinit_config.web_config.rendered
  description = "Cloud-init configuration string"
}
