#!/bin/bash
#https://ericeikrem.com/loki-promtail/

sudo mkdir -p /opt/promtail

sudo wget -qO /opt/promtail/promtail-linux-amd64.gz "https://github.com/grafana/loki/releases/download/v2.7.3/promtail-linux-amd64.zip"

sudo gunzip /opt/promtail/promtail-linux-amd64.gz
sudo chmod a+x /opt/promtail/promtail-linux-amd64
sudo ln -s /opt/promtail/promtail-linux-amd64 /usr/local/bin/promtail

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
  - url: http://192.168.4.111:3100/loki/api/v1/push

scrape_configs:
- job_name: messages
  static_configs:
  - targets:
      - localhost
    labels:
      job: varlogs
      __path__: /var/log/messages
- job_name: boot
  static_configs:
  - targets:
      - localhost
    labels:
      job: bootlog
      __path__: /var/log/boot.log
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
Environment="HOSTNAME=%H"
ExecStart=/opt/promtail/promtail-linux-amd64 --config.file=/opt/promtail/config-promtail.yaml --client.external-labels=host=\${HOSTNAME} -config.expand-env=true
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
