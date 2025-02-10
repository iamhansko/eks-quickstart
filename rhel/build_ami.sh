#!/bin/bash
sudo dnf update -y
sudo dnf groupinstall -y "Development Tools"

sudo dnf install -y git
git clone https://github.com/aws-samples/amazon-eks-ami-rhel.git
sudo chmod -R +x ./amazon-eks-ami-rhel/*
cd amazon-eks-ami-rhel

sudo mkdir -p /etc/eks/log-collector-script/
sudo cp -v ./log-collector-script/linux/eks-log-collector.sh /etc/eks/log-collector-script/

sudo cp -rv ./templates/rhel/runtime/rootfs/* /

sudo chmod -R a+x ./templates/shared/runtime/bin/
sudo cp -rv ./templates/shared/runtime/bin/* /usr/bin/

export ENABLE_FIPS=false
./templates/rhel/provisioners/enable-fips.sh

export ENABLE_EFA=false
./templates/rhel/provisioners/limit-c-states.sh

export AWS_ACCESS_KEY_ID=""
export AWS_CLI_URL=""
export AWS_REGION="ap-northeast-2"
export AWS_SECRET_ACCESS_KEY=""
export AWS_SESSION_TOKEN=""
export BINARY_BUCKET_NAME="amazon-eks"
export BINARY_BUCKET_REGION="ap-northeast-2"
export CONTAINER_SELINUX_VERSION="*"
export CONTAINERD_URL="https://api.github.com/repos/containerd/containerd/releases"
export CONTAINERD_VERSION="1.7.24"
# https://github.com/aws-samples/amazon-eks-ami-rhel/blob/main/doc/usage/overview.md#using-the-latest
export KUBERNETES_BUILD_DATE="2025-01-10"
export KUBERNETES_VERSION="1.31.4"
export NERDCTL_URL="https://api.github.com/repos/containerd/nerdctl/releases"
export NERDCTL_VERSION="*"
export RUNC_VERSION="*"
export SSM_AGENT_VERSION=""
export WORKING_DIR="./worker"
mkdir -p ./worker/shared
sudo cp -rv ./templates/shared/runtime/* ./worker/shared/
./templates/rhel/provisioners/install-worker.sh

export BUILD_IMAGE="public.ecr.aws/eks-distro-build-tooling/golang:1.23"
export PROJECT_DIR="./nodeadm"
./templates/rhel/provisioners/install-nodeadm.sh

# https://github.com/awslabs/amazon-eks-ami/blob/main/doc/usage/al2023.md#pause-container-image
# https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/add-ons-images.html
export PAUSE_CONTAINER_IMAGE="602401143452.dkr.ecr.ap-northeast-2.amazonaws.com/eks/pause:3.10"
./templates/rhel/provisioners/cache-pause-container.sh

./templates/rhel/provisioners/install-efa.sh

./templates/shared/provisioners/cleanup.sh

./templates/rhel/provisioners/validate.sh

sudo systemctl restart NetworkManager

export AMI_NAME="amazon-eks-ami-rhel"
TOKEN=`curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
export INSTANCE_ID=`curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id`
aws ec2 create-image --instance-id $INSTANCE_ID --name $AMI_NAME