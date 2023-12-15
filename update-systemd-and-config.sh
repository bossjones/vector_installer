#!/usr/bin/env sh

if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root"
  exit 1
fi

set -x

mkdir -p /etc/vector || true
cp -a ./vector/vector.yaml /etc/vector/vector.yaml

# create a heredoc that writes to overrides.conf
# mkdir -p /etc/systemd/system/promtail.service.d/ || true
cat <<EOF >/etc/systemd/system/vector.service
[Unit]
Description=Vector
Documentation=https://vector.dev
After=network-online.target
Requires=network-online.target

[Service]
User=root
Group=root
StandardOutput=journal+console
StandardError=inherit
ExecStartPre=/usr/local/bin/vector --config /etc/vector/vector.yaml validate
ExecStart=/usr/local/bin/vector --watch-config --verbose --config /etc/vector/vector.yaml
ExecReload=/usr/local/bin/vector --config /etc/vector/vector.yaml validate
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
AmbientCapabilities=CAP_NET_BIND_SERVICE
EnvironmentFile=-/etc/default/vector
Environment=VECTOR_LOG=debug
# Since systemd 229, should be in [Unit] but in order to support systemd <229,
# it is also supported to have it here.
StartLimitInterval=10
StartLimitBurst=5
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload &&
  systemctl restart vector &&
  systemctl enable vector
