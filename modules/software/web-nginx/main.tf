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

      runcmd:
        - systemctl enable nginx
        - |
          IP=$(hostname -I | awk '{print $1}')
          cat <<HTML > /var/www/html/index.html
          <h1>Welcome to ${var.app_name}</h1>
          <p>IP: $IP</p>
          HTML
        - systemctl restart nginx
    EOF
  }
}

###############################################################################

output "user_data_rendered" {
  value       = data.cloudinit_config.web_config.rendered
  description = "Cloud-init configuration string"
}
