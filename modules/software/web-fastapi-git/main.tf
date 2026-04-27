data "cloudinit_config" "fastapi_config" {
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
        - curl
        - python3-venv
        - libpq-dev

      write_files:
        - path: /opt/webapp/.env
          permissions: '0600'
          content: |
            DB_HOST=${var.db_host}
            DB_PORT=${var.db_port}
            DB_NAME=${var.db_name}
            DB_USER=${var.db_user}
            DB_PASS=${var.db_password}

        - path: /etc/nginx/sites-available/default
          content: |
            server {
                listen 80 default_server;
                location / {
                    proxy_pass http://127.0.0.1:8080;
                    proxy_set_header Host $host;
                    proxy_set_header X-Real-IP $remote_addr;
                }
            }

      runcmd:
        - curl -sSL https://install.python-poetry.org | POETRY_HOME=/opt/poetry python3 -
        - ln -s /opt/poetry/bin/poetry /usr/bin/poetry

        - git clone -b ${var.git_branch} ${var.git_repo_url} /opt/webapp/src

        - cd /opt/webapp/src
        - poetry install --no-root

        - |
          cat > /etc/systemd/system/fastapi.service << 'UNIT'
          [Unit]
          Description=FastAPI Resilience WebApp
          After=network.target

          [Service]
          User=root
          WorkingDirectory=/opt/webapp/src
          EnvironmentFile=/opt/webapp/.env
          ExecStart=/usr/bin/poetry run uvicorn main:app --host 127.0.0.1 --port 8080
          Restart=always
          RestartSec=3

          [Install]
          WantedBy=multi-user.target
          UNIT
        - systemctl daemon-reload
        - systemctl enable fastapi
        - systemctl start fastapi
        - systemctl restart nginx
    EOF
  }
}

output "user_data_rendered" {
  value = data.cloudinit_config.fastapi_config.rendered
}
