################################# Cloud Init ##################################

# --- PRIMARY node cloud-init ---
data "cloudinit_config" "db_primary" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content      = <<-EOF
      #cloud-config
      package_update: true
      packages:
        - postgresql
        - postgresql-contrib
        - python3-pip
        - python3-venv
        - etcd-server
        - etcd-client

      write_files:
        - path: /etc/systemd/system/etcd.service.d/override.conf
          content: |
            [Service]
            TimeoutStartSec=0
            Restart=always
            RestartSec=5

        - path: /etc/default/etcd
          content: |
            ETCD_NAME="node1"
            ETCD_DATA_DIR="/var/lib/etcd/default"
            ETCD_LISTEN_PEER_URLS="http://${var.primary_ip}:2380"
            ETCD_LISTEN_CLIENT_URLS="http://${var.primary_ip}:2379,http://127.0.0.1:2379"
            ETCD_INITIAL_ADVERTISE_PEER_URLS="http://${var.primary_ip}:2380"
            ETCD_ADVERTISE_CLIENT_URLS="http://${var.primary_ip}:2379"
            ETCD_INITIAL_CLUSTER="node1=http://${var.primary_ip}:2380,node2=http://${var.replica_ip}:2380"
            ETCD_INITIAL_CLUSTER_STATE="new"
            ETCD_INITIAL_CLUSTER_TOKEN="${var.app_name}-etcd-cluster"

        - path: /etc/patroni/patroni.yml
          content: |
            scope: ${var.app_name}-cluster
            name: node1

            restapi:
              listen: 0.0.0.0:8008
              connect_address: ${var.primary_ip}:8008

            etcd3:
              hosts: ${var.primary_ip}:2379,${var.replica_ip}:2379

            bootstrap:
              dcs:
                ttl: 30
                loop_wait: 10
                retry_timeout: 10
                maximum_lag_on_failover: 1048576
                postgresql:
                  use_pg_rewind: true
                  parameters:
                    wal_level: replica
                    hot_standby: "on"
                    max_wal_senders: 5
                    max_replication_slots: 5
                    wal_log_hints: "on"

              initdb:
                - encoding: UTF8
                - data-checksums

              pg_hba:
                - host replication replicator 0.0.0.0/0 md5
                - host all all 0.0.0.0/0 md5

              users:
                ${var.db_user}:
                  password: "${var.db_password}"
                  options:
                    - createrole
                    - createdb
                replicator:
                  password: "${var.replication_password}"
                  options:
                    - replication

            postgresql:
              listen: 0.0.0.0:5432
              connect_address: ${var.primary_ip}:5432
              data_dir: /var/lib/postgresql/data/patroni
              authentication:
                superuser:
                  username: postgres
                  password: "${var.postgres_password}"
                replication:
                  username: replicator
                  password: "${var.replication_password}"

      runcmd:
        - systemctl stop postgresql
        - systemctl disable postgresql
        - python3 -m venv /opt/patroni-venv
        - /opt/patroni-venv/bin/pip install patroni[etcd3] psycopg2-binary
        - mkdir -p /var/lib/postgresql/data/patroni
        - chown -R postgres:postgres /var/lib/postgresql/data/patroni
        - chmod 700 /var/lib/postgresql/data/patroni
        - |
          cat > /etc/systemd/system/patroni.service << 'UNIT'
          [Unit]
          Description=Patroni PostgreSQL HA
          After=network.target etcd.service
          Wants=etcd.service

          [Service]
          Type=simple
          User=postgres
          Group=postgres
          ExecStart=/opt/patroni-venv/bin/patroni /etc/patroni/patroni.yml
          Restart=always
          RestartSec=5

          [Install]
          WantedBy=multi-user.target
          UNIT
        - systemctl daemon-reload
        - systemctl enable etcd
        - systemctl start etcd --no-block
        - |
          while ! ETCDCTL_API=3 etcdctl endpoint health; do
            echo "En attente du cluster etcd..."
            sleep 5
          done
        - systemctl enable patroni
        - systemctl start patroni
        - |
          while ! sudo -u postgres pg_isready -h 127.0.0.1 -p 5432; do
            echo "En attente du demarrage de PostgreSQL par Patroni..."
            sleep 5
          done
        - |
          sudo -u postgres /opt/patroni-venv/bin/python -c "import psycopg2; conn = psycopg2.connect(host='127.0.0.1', port=5432, user='postgres', password='${var.postgres_password}'); conn.autocommit = True; cur = conn.cursor(); cur.execute(\"SELECT 1 FROM pg_database WHERE datname='${var.db_name}'\"); row = cur.fetchone(); cur.execute('CREATE DATABASE \"${var.db_name}\" OWNER \"${var.db_user}\"') if not row else None; conn.close()"
    EOF
  }
}

# --- REPLICA node cloud-init ---
data "cloudinit_config" "db_replica" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content      = <<-EOF
      #cloud-config
      package_update: true
      packages:
        - postgresql
        - postgresql-contrib
        - python3-pip
        - python3-venv
        - etcd-server
        - etcd-client

      write_files:
        - path: /etc/systemd/system/etcd.service.d/override.conf
          content: |
            [Service]
            TimeoutStartSec=0
            Restart=always
            RestartSec=5

        - path: /etc/default/etcd
          content: |
            ETCD_NAME="node2"
            ETCD_DATA_DIR="/var/lib/etcd/default"
            ETCD_LISTEN_PEER_URLS="http://${var.replica_ip}:2380"
            ETCD_LISTEN_CLIENT_URLS="http://${var.replica_ip}:2379,http://127.0.0.1:2379"
            ETCD_INITIAL_ADVERTISE_PEER_URLS="http://${var.replica_ip}:2380"
            ETCD_ADVERTISE_CLIENT_URLS="http://${var.replica_ip}:2379"
            ETCD_INITIAL_CLUSTER="node1=http://${var.primary_ip}:2380,node2=http://${var.replica_ip}:2380"
            ETCD_INITIAL_CLUSTER_STATE="new"
            ETCD_INITIAL_CLUSTER_TOKEN="${var.app_name}-etcd-cluster"

        - path: /etc/patroni/patroni.yml
          content: |
            scope: ${var.app_name}-cluster
            name: node2

            restapi:
              listen: 0.0.0.0:8008
              connect_address: ${var.replica_ip}:8008

            etcd3:
              hosts: ${var.primary_ip}:2379,${var.replica_ip}:2379

            bootstrap:
              dcs:
                ttl: 30
                loop_wait: 10
                retry_timeout: 10
                maximum_lag_on_failover: 1048576
                postgresql:
                  use_pg_rewind: true
                  parameters:
                    wal_level: replica
                    hot_standby: "on"
                    max_wal_senders: 5
                    max_replication_slots: 5
                    wal_log_hints: "on"

              initdb:
                - encoding: UTF8
                - data-checksums

              pg_hba:
                - host replication replicator 0.0.0.0/0 md5
                - host all all 0.0.0.0/0 md5

              users:
                ${var.db_user}:
                  password: "${var.db_password}"
                  options:
                    - createrole
                    - createdb
                replicator:
                  password: "${var.replication_password}"
                  options:
                    - replication

            postgresql:
              listen: 0.0.0.0:5432
              connect_address: ${var.replica_ip}:5432
              data_dir: /var/lib/postgresql/data/patroni
              authentication:
                superuser:
                  username: postgres
                  password: "${var.postgres_password}"
                replication:
                  username: replicator
                  password: "${var.replication_password}"

      runcmd:
        - systemctl stop postgresql
        - systemctl disable postgresql
        - python3 -m venv /opt/patroni-venv
        - /opt/patroni-venv/bin/pip install patroni[etcd3] psycopg2-binary
        - mkdir -p /var/lib/postgresql/data/patroni
        - chown -R postgres:postgres /var/lib/postgresql/data/patroni
        - chmod 700 /var/lib/postgresql/data/patroni
        - |
          cat > /etc/systemd/system/patroni.service << 'UNIT'
          [Unit]
          Description=Patroni PostgreSQL HA
          After=network.target etcd.service
          Wants=etcd.service

          [Service]
          Type=simple
          User=postgres
          Group=postgres
          ExecStart=/opt/patroni-venv/bin/patroni /etc/patroni/patroni.yml
          Restart=always
          RestartSec=5

          [Install]
          WantedBy=multi-user.target
          UNIT
        - systemctl daemon-reload
        - systemctl enable etcd
        - systemctl start etcd --no-block
        - |
          while ! ETCDCTL_API=3 etcdctl endpoint health; do
            echo "En attente du cluster etcd..."
            sleep 5
          done
        - systemctl enable patroni
        - systemctl start patroni
    EOF
  }
}
###############################################################################
