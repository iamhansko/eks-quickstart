#!/bin/bash
mkdir -p /home/ec2-user/bin
curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.30.0/2024-05-12/bin/linux/amd64/kubectl
chmod +x kubectl
mv kubectl /home/ec2-user/bin/kubectl
export PATH=/home/ec2-user/bin:$PATH
echo "export PATH=/home/ec2-user/bin:$PATH" >> ~/.bashrc
echo "alias k=kubectl" >>~/.bashrc
echo "complete -o default -F __start_kubectl k" >>~/.bashrc
echo "source <(kubectl completion bash)" >>~/.bashrc

curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 > /home/ec2-user/get_helm.sh
chmod 700 /home/ec2-user/get_helm.sh
/home/ec2-user/get_helm.sh

exec bash