#!/bin/bash
#https://ericeikrem.com/loki-promtail/

sudo mkdir -p /opt/loki

sudo wget -qO /opt/loki/loki-linux-amd64.gz "https://github.com/grafana/loki/releases/download/v2.7.3/loki-linux-amd64.zip"

sudo gunzip /opt/loki/loki-linux-amd64.gz
sudo chmod a+x /opt/loki/loki-linux-amd64
sudo ln -s /opt/loki/loki /usr/local/bin/loki

sudo useradd --system loki
sudo usermod -a -G adm loki

sudo chown -R loki:loki /opt/loki

cat >> /opt/loki/config-loki.yaml << EOF
auth_enabled: false
server:
  http_listen_port: 3100
ingester:
  lifecycler:
    address: 127.0.0.1
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
    final_sleep: 0s
  chunk_idle_period: 5m
  chunk_retain_period: 30s
schema_config:
  configs:
  - from: 2020-05-15
    store: boltdb
    object_store: filesystem
    schema: v11
    index:
      prefix: index_
      period: 168h
storage_config:
  boltdb:
    directory: /tmp/loki/index
  filesystem:
    directory: /tmp/loki/chunks
limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h
  max_entries_limit_per_query: 500000
chunk_store_config:
  max_look_back_period: 0
table_manager:
  chunk_tables_provisioning:
    inactive_read_throughput: 0
    inactive_write_throughput: 0
    provisioned_read_throughput: 0
    provisioned_write_throughput: 0
  index_tables_provisioning:
    inactive_read_throughput: 0
    inactive_write_throughput: 0
    provisioned_read_throughput: 0
    provisioned_write_throughput: 0
  retention_deletes_enabled: false
  retention_period: 0
EOF


cat >>  /etc/systemd/system/loki.service << EOF
[Unit]
Description=Loki
After=network.target

[Service]
Type=notify-reload
User=loki
Group=adm
WorkingDirectory=/opt/loki
ExecStart=/opt/loki/loki-linux-amd64 --config.file=/opt/loki/config-loki.yaml
SuccessExitStatus=143
Restart=always
RestartSec=5
TimeoutStopSec=10
WatchdogSec=180

[Install]
WantedBy=multi-user.target
EOF


sudo chown -R loki:loki /opt/loki
sudo systemctl daemon-reload
sudo systemctl enable loki.service
sudo systemctl restart loki.service
