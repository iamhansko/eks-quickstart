#!/bin/bash
# export aws_region=""
# export cluster_name=""
source /home/ec2-user/.bashrc
vpc_id=$(aws eks describe-cluster --name $cluster_name --query "cluster.resourcesVpcConfig.vpcId" --output text)
account_id=$(aws sts get-caller-identity --query "Account" --output text)

# https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/lbc-helm.html

oidc_id=$(aws eks describe-cluster --name $cluster_name --query "cluster.identity.oidc.issuer" --output text | cut -d '/' -f 5)
echo $oidc_id
eksctl utils associate-iam-oidc-provider --cluster $cluster_name --approve
aws iam list-open-id-connect-providers | grep $oidc_id | cut -d "/" -f4

curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.2/docs/install/iam_policy.json
aws iam create-policy \
--policy-name AWSLoadBalancerControllerIAMPolicy \
--policy-document file://iam_policy.json
rm iam_policy.json

eksctl create iamserviceaccount \
--cluster=$cluster_name \
--namespace=kube-system \
--name=aws-load-balancer-controller \
--role-name AmazonEKSLoadBalancerControllerRole \
--attach-policy-arn="arn:aws:iam::$account_id:policy/AWSLoadBalancerControllerIAMPolicy" \
--approve --region $aws_region
helm repo add eks https://aws.github.io/eks-charts
helm repo update eks
helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system \
--set clusterName=$cluster_name \
--set serviceAccount.create=false \
--set serviceAccount.name=aws-load-balancer-controller \
--set region=$aws_region \
--set vpcId=$vpc_id
kubectl rollout status -n kube-system deploy aws-load-balancer-controller

# kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

git clone https://codeberg.org/hjacobs/kube-ops-view.git
cd kube-ops-view/
kubectl apply -k deploy
kubectl patch svc kube-ops-view -p "{\"spec\": {\"type\": \"LoadBalancer\"}}"