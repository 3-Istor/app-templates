data "cloudinit_config" "git_config" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content      = <<-EOF
      #cloud-config
      package_update: true
      packages:
        - nginx
        - git

      runcmd:
        # Remove default nginx page
        - rm -rf /var/www/html/*
        # Clone the repository
        - git clone -b ${var.git_branch} ${var.git_repo_url} /var/www/html/
        # Set correct permissions for Nginx
        - chown -R www-data:www-data /var/www/html/
        # Enable and restart Nginx
        - systemctl enable nginx
        - systemctl restart nginx
    EOF
  }
}

output "user_data_rendered" {
  value       = data.cloudinit_config.git_config.rendered
  description = "Cloud-init configuration string for Git deployment"
}
