locals {
  app_script = <<-EOF
import os, socket, psycopg2
from flask import Flask

app = Flask(__name__)

DB_HOST = "${var.db_host}"
DB_PORT = "${var.db_port}"
DB_USER = "${var.db_user}"
DB_PASS = "${var.db_password}"
DB_NAME = "${var.db_name}"

def get_db():
    conn = psycopg2.connect(host=DB_HOST, port=DB_PORT, user=DB_USER, password=DB_PASS, dbname=DB_NAME, connect_timeout=2)
    conn.autocommit = True
    return conn

@app.route("/")
def index():
    app_ip = socket.gethostbyname(socket.gethostname())
    try:
        conn = get_db()
        cur = conn.cursor()
        cur.execute("CREATE TABLE IF NOT EXISTS hits (id SERIAL PRIMARY KEY, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);")
        cur.execute("INSERT INTO hits DEFAULT VALUES;")
        cur.execute("SELECT COUNT(*) FROM hits;")
        hits = cur.fetchone()[0]

        cur.execute("SELECT inet_server_addr();")
        db_leader_ip = cur.fetchone()[0]
        conn.close()

        return f"""
        <html>
            <head><meta http-equiv="refresh" content="3"></head>
            <body style="font-family: Arial; text-align: center; margin-top: 50px;">
                <h1>🚀 Resilience Demo (Global Template)</h1>
                <h2>💻 Web Node Actuel : <span style="color: blue;">{app_ip}</span></h2>
                <h2>🐘 DB Leader Node : <span style="color: green;">{db_leader_ip}</span></h2>
                <h3>📊 Nombre total de visites (DB) : {hits}</h3>
                <p><i>Tuez une VM DB pour tester le Failover Patroni ! (Temps de bascule: ~35s)</i></p>
                <p><i>Tuez une VM Web pour tester le Load Balancing Applicatif !</i></p>
            </body>
        </html>
        """, 200
    except Exception as e:
        return f"""
        <html>
            <head><meta http-equiv="refresh" content="2"></head>
            <body style="font-family: Arial; text-align: center; margin-top: 50px; background-color: #ffe6e6;">
                <h1>🔄 Failover DB en cours...</h1>
                <h2>💻 Web Node Actuel : <span style="color: blue;">{app_ip}</span></h2>
                <h3 style="color: red;">La base de données principale est tombée !</h3>
                <p>L'élection du nouveau Leader est en cours... (Patientez environ 30 secondes)</p>
                <hr>
                <small style="color: gray;">Erreur interne : {e}</small>
            </body>
        </html>
        """, 200

if __name__ == "__main__":
    app.run(host="127.0.0.1", port=8080, threaded=True)
EOF
}

data "cloudinit_config" "app_config" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content      = <<-EOF
      #cloud-config
      package_update: true
      packages:
        - nginx
        - python3-pip
        - python3-venv
        - libpq-dev

      write_files:
        - path: /opt/webapp/app.py
          permissions: '0644'
          content: ${base64encode(local.app_script)}
          encoding: b64

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
        - python3 -m venv /opt/webapp/venv
        - /opt/webapp/venv/bin/pip install flask psycopg2-binary
        - |
          cat > /etc/systemd/system/webapp.service << 'UNIT'
          [Unit]
          Description=Python Flask WebApp Demo
          After=network.target

          [Service]
          User=root
          WorkingDirectory=/opt/webapp
          ExecStart=/opt/webapp/venv/bin/python /opt/webapp/app.py
          Restart=always
          RestartSec=3

          [Install]
          WantedBy=multi-user.target
          UNIT
        - systemctl daemon-reload
        - systemctl enable webapp
        - systemctl start webapp
        - systemctl restart nginx
    EOF
  }
}

output "user_data_rendered" {
  value = data.cloudinit_config.app_config.rendered
}
