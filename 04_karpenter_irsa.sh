#!/bin/bash
set -o xtrace

# Install Karpenter
export CLUSTER_NAME="hyunsu-cluster" # Change Me
export AWS_DEFAULT_REGION="us-east-1" # Change Me
export AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
export TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
export EC2_IAM_ROLE=`curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/iam/security-credentials`
export EC2_IAM_ROLE_ARN="arn:aws:iam::$AWS_ACCOUNT_ID:role/$EC2_IAM_ROLE"
aws eks create-access-entry \
--cluster-name $CLUSTER_NAME \
--principal-arn $EC2_IAM_ROLE_ARN \
--type STANDARD
aws eks associate-access-policy \
--cluster-name $CLUSTER_NAME \
--principal-arn $EC2_IAM_ROLE_ARN \
--access-scope type=cluster \
--policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy

# code-server
export HOME=/home/ec2-user
sudo dnf update -yq
sudo dnf install -yq git
sudo dnf groupinstall -yq "Development Tools"
curl -fsSL https://code-server.dev/install.sh | sh
mkdir -p /home/ec2-user/.config/code-server
cat <<EOF > /home/ec2-user/.config/code-server/config.yaml
bind-addr: 0.0.0.0:8000
auth: none
cert: false
EOF
sudo chown -R ec2-user:ec2-user /home/ec2-user/.config
sudo mkdir -p /etc/systemd/system/code-server@.service.d
sudo echo -e "[Service]\nExecStart=\nExecStart=/usr/bin/code-server /home/ec2-user" > /etc/systemd/system/code-server@.service.d/override.conf
sudo systemctl daemon-reload
sudo systemctl enable --now code-server@ec2-user

# kubectl
sudo dnf install -yq bash-completion
curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.32.0/2024-12-20/bin/linux/amd64/kubectl
chmod +x ./kubectl
mkdir -p $HOME/bin && cp ./kubectl $HOME/bin/kubectl && export PATH=$HOME/bin:$PATH
echo 'export PATH=$HOME/bin:$PATH' >> ~/.bashrc
kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
echo 'alias k=kubectl' >>~/.bashrc
echo 'complete -o default -F __start_kubectl k' >>~/.bashrc

# eksctl
export ARCH=amd64
export PLATFORM=$(uname -s)_$ARCH
curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"
tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp && rm eksctl_$PLATFORM.tar.gz
sudo mv /tmp/eksctl /usr/local/bin

# helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
sudo chown ec2-user:ec2-user /home/ec2-user/.cache

# terraform
sudo yum install -y yum-utils shadow-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo yum -y install terraform

# eks-node-viewer
wget -O eks-node-viewer https://github.com/awslabs/eks-node-viewer/releases/download/v0.7.1/eks-node-viewer_Linux_x86_64
chmod +x eks-node-viewer
sudo mv -v eks-node-viewer /usr/local/bin

export KARPENTER_NAMESPACE="kube-system"
export KARPENTER_VERSION="1.4.0"
export K8S_VERSION="1.32"
export AWS_PARTITION="aws" 
export TEMPOUT="$(mktemp)"
export ALIAS_VERSION="$(aws ssm get-parameter --name "/aws/service/eks/optimized-ami/${K8S_VERSION}/amazon-linux-2023/x86_64/standard/recommended/image_id" --query Parameter.Value | xargs aws ec2 describe-images --query 'Images[0].Name' --image-ids | sed -r 's/^.*(v[[:digit:]]+).*$/\1/')"
echo "${KARPENTER_NAMESPACE}" "${KARPENTER_VERSION}" "${K8S_VERSION}" "${CLUSTER_NAME}" "${AWS_DEFAULT_REGION}" "${AWS_ACCOUNT_ID}" "${TEMPOUT}" "${ARM_AMI_ID}" "${AMD_AMI_ID}" "${GPU_AMI_ID}"

curl -fsSL https://raw.githubusercontent.com/aws/karpenter-provider-aws/v"${KARPENTER_VERSION}"/website/content/en/preview/getting-started/getting-started-with-karpenter/cloudformation.yaml  > "${TEMPOUT}" \
&& aws cloudformation deploy \
--stack-name "Karpenter-${CLUSTER_NAME}" \
--template-file "${TEMPOUT}" \
--capabilities CAPABILITY_NAMED_IAM \
--parameter-overrides "ClusterName=${CLUSTER_NAME}"

eksctl utils associate-iam-oidc-provider --cluster $CLUSTER_NAME --approve
eksctl create iamserviceaccount \
--cluster "$CLUSTER_NAME" --name karpenter --namespace $KARPENTER_NAMESPACE \
--role-name "$CLUSTER_NAME-karpenter" \
--attach-policy-arn "arn:aws:iam::$AWS_ACCOUNT_ID:policy/KarpenterControllerPolicy-$CLUSTER_NAME" \
--role-only \
--approve
export KARPENTER_IAM_ROLE_ARN="arn:${AWS_PARTITION}:iam::${AWS_ACCOUNT_ID}:role/${CLUSTER_NAME}-karpenter"

aws eks update-kubeconfig --name $CLUSTER_NAME
helm registry logout public.ecr.aws
helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter \
--version "${KARPENTER_VERSION}" \
--namespace "${KARPENTER_NAMESPACE}" --create-namespace \
--set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=${KARPENTER_IAM_ROLE_ARN} \
--set "settings.clusterName=${CLUSTER_NAME}" \
--set "settings.interruptionQueue=${CLUSTER_NAME}" \
--set "settings.reservedENIs=1" \
--set controller.resources.requests.cpu=1 \
--set controller.resources.requests.memory=1Gi \
--set controller.resources.limits.cpu=1 \
--set controller.resources.limits.memory=1Gi \
--wait

export NODE_IAM_ROLE_ARN="arn:aws:iam::$AWS_ACCOUNT_ID:role/KarpenterNodeRole-$CLUSTER_NAME"
aws eks create-access-entry --cluster-name $CLUSTER_NAME --principal-arn $NODE_IAM_ROLE_ARN --type EC2_LINUX

sudo chown -R ec2-user:ec2-user /home/ec2-user/.kube

aws iam create-service-linked-role --aws-service-name spot.amazonaws.com