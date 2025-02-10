#!/bin/bash

# https://docs.aws.amazon.com/ko_kr/AWSEC2/latest/UserGuide/ec2-instance-connect-set-up.html#ec2-instance-connect-install
mkdir /tmp/ec2-instance-connect
curl https://amazon-ec2-instance-connect-us-west-2.s3.us-west-2.amazonaws.com/latest/linux_amd64/ec2-instance-connect.rhel8.rpm -o /tmp/ec2-instance-connect/ec2-instance-connect.rpm
curl https://amazon-ec2-instance-connect-us-west-2.s3.us-west-2.amazonaws.com/latest/linux_amd64/ec2-instance-connect-selinux.noarch.rpm -o /tmp/ec2-instance-connect/ec2-instance-connect-selinux.rpm
sudo yum install -y /tmp/ec2-instance-connect/ec2-instance-connect.rpm /tmp/ec2-instance-connect/ec2-instance-connect-selinux.rpm

# VS Code Server
export HOME=/home/ec2-user
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