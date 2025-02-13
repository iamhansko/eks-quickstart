#!/bin/bash
# echo "aws_region='us-east-1'" >>/home/ec2-user/.bashrc
# echo "cluster_name='basic'" >>/home/ec2-user/.bashrc
source /home/ec2-user/.bashrc

mkdir -p /home/ec2-user/bin
curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.30.0/2024-05-12/bin/linux/amd64/kubectl
chmod +x kubectl
mv kubectl /home/ec2-user/bin/kubectl
export PATH=/home/ec2-user/bin:$PATH
echo "export PATH=/home/ec2-user/bin:$PATH" >> ~/.bashrc
echo "alias k=kubectl" >>~/.bashrc
echo "complete -o default -F __start_kubectl k" >>~/.bashrc
echo "source <(kubectl completion bash)" >>~/.bashrc

aws eks update-kubeconfig --region $aws_region --name $cluster_name

curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
aws configure set region $aws_region

curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 > /home/ec2-user/get_helm.sh
chmod 700 /home/ec2-user/get_helm.sh
/home/ec2-user/get_helm.sh

vpc_id=$(aws eks describe-cluster --name $cluster_name --query "cluster.resourcesVpcConfig.vpcId" --output text)
public_subnets=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" "Name=tag:Name,Values=*public*" --query 'Subnets[*].SubnetId' --output text)
private_subnets=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" "Name=tag:Name,Values=*private*" --query 'Subnets[*].SubnetId' --output text)
echo $public_subnets | xargs -n1 aws ec2 modify-subnet-attribute --map-public-ip-on-launch --subnet-id
aws ec2 create-tags --resources $public_subnets --tags Key=kubernetes.io/role/elb,Value=1
aws ec2 create-tags --resources $private_subnets --tags Key=kubernetes.io/role/internal-elb,Value=1

bastion_id=$(ec2-metadata -i | cut -d " " -f 2)
cluster_sg=$(aws eks describe-cluster --name $cluster_name --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' --output text)
bastion_sg=$(aws ec2 describe-instances --instance-ids $bastion_id --query 'Reservations[].Instances[].SecurityGroups[].GroupId' --output text)
aws ec2 modify-instance-attribute --instance-id $bastion_id --groups $bastion_sg $cluster_sg

exec bash