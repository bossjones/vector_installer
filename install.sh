#!/usr/bin/env sh

# Usage:
#   curl ... | ENV_VAR=... sh -
#       or
#   ENV_VAR=... ./install.sh
#
# Example:
#   Installing Node exporter enabling only os collector:
#     curl ... | INSTALL_NODE_EXPORTER="--collector.disable-defaults --collector.os" sh -
#   Installing Node exporter enabling only os collector:
#     curl ... | sh -s - --collector.disable-defaults --collector.os
#
# Environment variables:
#   - INSTALL_NODE_EXPORTER_SKIP_DOWNLOAD
#     If set to true will not download Node exporter hash or binary
#
#   - INSTALL_NODE_EXPORTER_FORCE_RESTART
#     If set to true will always restart the Node exporter service
#
#   - INSTALL_NODE_EXPORTER_SKIP_ENABLE
#     If set to true will not enable or start Node exporter service
#
#   - INSTALL_NODE_EXPORTER_SKIP_START
#     If set to true will not start Node exporter service
#
#   - INSTALL_NODE_EXPORTER_SKIP_FIREWALL
#     If set to true will not add firewall rules
#
#   - INSTALL_NODE_EXPORTER_SKIP_SELINUX
#     If set to true will not change SELinux context for binary
#
#   - INSTALL_NODE_EXPORTER_VERSION
#     Version of Node exporter to download from GitHub
#
#   - INSTALL_NODE_EXPORTER_BIN_DIR
#     Directory to install Node exporter binary, and uninstall script to, or use
#     /usr/local/bin as the default
#
#   - INSTALL_NODE_EXPORTER_SYSTEMD_DIR
#     Directory to install systemd service files, or use
#     /etc/systemd/system as the default
#
#   - INSTALL_NODE_EXPORTER_EXEC or script arguments
#     Command with flags to use for launching Node exporter service
#
#     The following commands result in the same behavior:
#       curl ... | INSTALL_NODE_EXPORTER_EXEC="--collector.disable-defaults --collector.os" sh -s -
#       curl ... | INSTALL_NODE_EXPORTER_EXEC="--collector.disable-defaults" sh -s - --collector.os
#       curl ... | sh -s - --collector.disable-defaults --collector.os
#

if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root"
  exit 1
fi

apt update
apt install -y curl wget

# ------------------------------------------------------------------------------

# Add vector:vector user & group
id --user vector >/dev/null 2>&1 ||
  useradd --system --shell /sbin/nologin --home-dir /var/lib/vector --user-group \
    --comment "Vector observability data router" vector

# Create default Vector data directory
mkdir -p /var/lib/vector

# Make vector:vector the owner of the Vector data directory
chown -R vector:vector /var/lib/vector
# ------------------------------------------------------------------------------

curl --proto '=https' --tlsv1.2 -sSfL https://sh.vector.dev | bash -s -- -y

set -x

cp -a ~/.vector/bin/vector /usr/local/bin/vector

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
ExecStartPre=/usr/local/bin/vector --config /etc/vector/vector.yaml validate
ExecStart=/usr/local/bin/vector --verbose --config /etc/vector/vector.yaml
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

# Add Vector to adm group to read /var/logs
usermod --append --groups adm vector || true

if getent group 'systemd-journal'; then
  # Add Vector to systemd-journal to read journald logs
  usermod --append --groups systemd-journal vector || true
  systemctl daemon-reload || true
fi

if getent group 'systemd-journal-remote'; then
  # Add Vector to systemd-journal-remote to read remote journald logs
  usermod --append --groups systemd-journal-remote vector || true
  systemctl daemon-reload || true
fi

systemctl daemon-reload || true
systemctl restart vector
systemctl enable vector
