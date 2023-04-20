#!/bin/bash
#https://ericeikrem.com/loki-promtail/

sudo mkdir -p /opt/promtail

sudo wget -qO /opt/promtail/promtail-linux-amd64.gz "https://github.com/grafana/loki/releases/download/v2.7.3/promtail-linux-amd64.zip"

sudo gunzip /opt/promtail/promtail-linux-amd64.gz
sudo chmod a+x /opt/promtail/promtail-linux-amd64
sudo ln -s /opt/promtail/promtail /usr/local/bin/promtail

sudo useradd --system promtail
sudo usermod -a -G adm promtail

sudo chown -R promtail:promtail /opt/promtail 

cat >> /opt/promtail/config-promtail.yaml << EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /opt/promtail/positions.yaml

clients:
  - url: http://localhost:3100/loki/api/v1/push

scrape_configs:
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: systemlogs
          __path__: /var/log/*log
  - job_name: ec2-logs
    ec2_sd_configs:
      - region: ap-south-1
        access_key: XXXXXXXXXXXXXXXXXX
        secret_key: XXXXXXXXXXXXXXXXXX
        port: 9080
    relabel_configs:
      - source_labels: [__meta_ec2_tag_Name]
        target_label: instance_name
      - source_labels: [__meta_ec2_instance_state]
        target_label: instance_state
        regex: running
        action: keep
      - action: replace
        replacement: /var/log/**.log
        target_label: __path__
      - source_labels: [__meta_ec2_private_dns_name]
        #regex: "(.*)"
        regex: '^(ip-[0-9]+-[0-9]+-[0-9]+-[0-9]+).*'
        replacement: '${1}'
        target_label: __host__
    pipeline_stages:
      - static_labels:
          job: ec2-logs
EOF


cat >>  /etc/systemd/system/promtail.service << EOF
[Unit]
Description=Promtail
After=network.target

[Service]
Type=notify-reload
User=promtail
Group=adm
WorkingDirectory=/opt/promtail
ExecStart=/opt/promtail/promtail-linux-amd64 --config.file=/opt/promtail/config-promtail.yaml -config.expand-env=true
SuccessExitStatus=143
Restart=always
RestartSec=5
TimeoutStopSec=10
WatchdogSec=180

[Install]
WantedBy=multi-user.target
EOF


sudo chown -R promtail:promtail /opt/promtail

sudo setfacl -R -m u:promtail:rX /var/log
sudo usermod -a -G adm promtail
sudo usermod -a -G systemd-journal promtail

sudo systemctl daemon-reload
sudo systemctl enable promtail.service
sudo systemctl restart promtail.service
