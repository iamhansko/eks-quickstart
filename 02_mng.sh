#!/bin/bash
# export aws_region=""
# export cluster_name=""
# echo "aws_region=''" >>/home/ec2-user/.bashrc
# echo "cluster_name=''" >>/home/ec2-user/.bashrc
source /home/ec2-user/.bashrc

k8s_version=$(aws eks describe-cluster --name $cluster_name --query cluster.version --output text)
# Amazon Linux 2
# ami_id=$(aws ssm get-parameter --name /aws/service/eks/optimized-ami/$k8s_version/amazon-linux-2/recommended/image_id --region $aws_region --query "Parameter.Value" --output text)
# Amazon Linux 2023
ami_id=$(aws ssm get-parameter --name /aws/service/eks/optimized-ami/$k8s_version/amazon-linux-2023/x86_64/standard/recommended/image_id --region $aws_region --query "Parameter.Value" --output text)
# certificate_authority=$(aws eks describe-cluster --query "cluster.certificateAuthority.data" --output text --name $cluster_name --region $aws_region)
# api_server_endpoint=$(aws eks describe-cluster --query "cluster.endpoint" --output text --name $cluster_name --region $aws_region)
# service_cidr=$(aws eks describe-cluster --query "cluster.kubernetesNetworkConfig.serviceIpv4Cidr" --output text --name $cluster_name --region $aws_region | sed 's/0.0\/16/0.10/')

vpc_id=$(aws eks describe-cluster --name $cluster_name --query "cluster.resourcesVpcConfig.vpcId" --output text)
sg_id=$(aws eks describe-cluster --name $cluster_name --query cluster.resourcesVpcConfig.clusterSecurityGroupId --output text)
public_subnets=($(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" "Name=tag:Name,Values=*public*" --query 'Subnets[*].SubnetId' --output text))
private_subnets=($(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" "Name=tag:Name,Values=*private*" --query 'Subnets[*].SubnetId' --output text))

mkdir -p /home/ec2-user/scripts
cat <<EOF > /home/ec2-user/scripts/al2023nodegroup.yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: $cluster_name
  region: $aws_region

vpc:
  id: $vpc_id
  securityGroup: $sg_id
  subnets:
    public:
      public1:
        id: ${public_subnets[0]}
      public2:
        id: ${public_subnets[1]}
    private:
      private1:
        id: ${private_subnets[0]}
      private2:
        id: ${private_subnets[1]}

managedNodeGroups:
  - name: al2023nodegroup
    # ami: $ami_id
    amiFamily: AmazonLinux2023 #or AmazonLinux2
    spot: true
    instanceType: t3.xlarge
    desiredCapacity: 3
    privateNetworking: true
    disableIMDSv1: true
    iam:
      attachPolicyARNs:
        - arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
        - arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
        - arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
        - arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
        - arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy
EOF

eksctl create nodegroup --config-file /home/ec2-user/scripts/al2023nodegroup.yaml