#!/bin/bash
# sudo dnf install -y git
# git clone https://github.com/aws-samples/amazon-eks-ami-rhel.git
sudo cp -rv ./amazon-eks-ami-rhel/templates/rhel/runtime/rootfs/* /
sudo chmod -R a+x ./amazon-eks-ami-rhel/templates/shared/runtime/bin/
sudo cp -rv ./amazon-eks-ami-rhel/templates/shared/runtime/bin/* /usr/bin/
sudo dnf install -y chrony conntrack ethtool ipvsadm jq nfs-utils python3 socat unzip wget mdadm pigz iptables runc criu libnet protobuf-c container-selinux device-mapper-persistent-data lvm2 lvm2-libs device-mapper-event device-mapper-event-libs libaio
sudo dnf install -y https://s3.ap-northeast-2.amazonaws.com/amazon-ssm-ap-northeast-2/latest/linux_amd64/amazon-ssm-agent.rpm
sudo wget https://github.com/containerd/containerd/releases/download/v1.7.24/containerd-1.7.24-linux-amd64.tar.gz
sudo tar Cxzvvf /usr containerd*.tar.gz
sudo systemctl daemon-reload
sudo systemctl enable --now containerd
sudo systemctl enable ebs-initialize-bin@containerd
sudo wget https://github.com/containerd/nerdctl/releases/download/v2.0.3/nerdctl-2.0.3-linux-amd64.tar.gz
sudo tar Cxzvvf /usr/bin nerdctl*.tar.gz
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
sudo ln -sv /usr/local/bin/aws /usr/bin/aws
sudo aws ecr get-login-password --region ap-northeast-2 | sudo nerdctl login --username AWS --password-stdin 602401143452.dkr.ecr.ap-northeast-2.amazonaws.com
sudo nerdctl pull public.ecr.aws/eks-distro-build-tooling/golang:1.23
sudo nerdctl pull 602401143452.dkr.ecr.ap-northeast-2.amazonaws.com/eks/pause:3.10