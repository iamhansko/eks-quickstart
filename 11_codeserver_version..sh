#!/bin/bash
set -o xtrace

export HOME=/home/ec2-user

dnf update -y
dnf install -y git
dnf groupinstall -y "Development Tools"
dnf install -y python3.12
python3.12 -m ensurepip --upgrade
python3.12 -m pip install --upgrade pip
ln -sf /usr/local/bin/pip3.12 /usr/bin/pip
ln -sf /usr/bin/python3.12 /usr/bin/python

export CODE_SERVER_VERSION="4.96.4"
wget https://github.com/coder/code-server/releases/download/v$CODE_SERVER_VERSION/code-server-$CODE_SERVER_VERSION-linux-amd64.tar.gz
tar -xzf code-server-$CODE_SERVER_VERSION-linux-amd64.tar.gz
mv code-server-$CODE_SERVER_VERSION-linux-amd64 /usr/local/lib/code-server
ln -s /usr/local/lib/code-server/bin/code-server /usr/local/bin/code-server
mkdir -p /home/ec2-user/.config/code-server
cat <<EOF > /home/ec2-user/.config/code-server/config.yaml
bind-addr: 0.0.0.0:8000
auth: none
cert: false
EOF
chown -R ec2-user:ec2-user /home/ec2-user/.config
cat <<EOF > /etc/systemd/system/code-server.service
[Unit]
Description=VS Code Server
After=network.target
[Service]
Type=simple
User=ec2-user
ExecStart=/usr/local/bin/code-server --config /home/ec2-user/.config/code-server/config.yaml /home/ec2-user
Restart=always
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now code-server