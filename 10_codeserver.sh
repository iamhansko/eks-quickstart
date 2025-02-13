#!/bin/bash

export HOME=/home/ec2-user

dnf update -y
dnf install -y git
dnf groupinstall -y "Development Tools"
dnf install -y python3.12
python3.12 -m ensurepip --upgrade
python3.12 -m pip install --upgrade pip
ln -sf /usr/local/bin/pip3.12 /usr/bin/pip
ln -sf /usr//bin/python3.12 /usr/bin/python

curl -fsSL https://code-server.dev/install.sh | sh
mkdir -p /home/ec2-user/.config/code-server
cat <<EOF > /home/ec2-user/.config/code-server/config.yaml
bind-addr: 0.0.0.0:8000
auth: none
cert: false
EOF
chown -R ec2-user:ec2-user /home/ec2-user/.config
mkdir -p /etc/systemd/system/code-server@.service.d
echo -e "[Service]\nExecStart=\nExecStart=/usr/bin/code-server /home/ec2-user" > /etc/systemd/system/code-server@.service.d/override.conf
systemctl daemon-reload
systemctl enable --now code-server@ec2-user