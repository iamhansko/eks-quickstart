#!/bin/bash
export CLUSTER_NAME=""
export AWS_REGION=""

export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
export CLUSTER_ENDPOINT="$(aws eks describe-cluster --name $CLUSTER_NAME --query "cluster.endpoint" --output text)"
export KARPENTER_NAMESPACE="kube-system"
echo Cluster Name:$CLUSTER_NAME AWS Region:$AWS_REGION Account ID:$AWS_ACCOUNT_ID Cluster Endpoint:$CLUSTER_ENDPOINT Karpenter Namespace:$KARPENTER_NAMESPACE

KARPENTER_VERSION_V=$(curl -sL "https://api.github.com/repos/aws/karpenter/releases/latest" | jq -r ".tag_name")
export KARPENTER_VERSION=$(echo $KARPENTER_VERSION_V | sed "s/^v//")
echo "Karpenter's Latest release version: $KARPENTER_VERSION"

export TEMPOUT=$(mktemp)
curl -fsSL https://raw.githubusercontent.com/aws/karpenter-provider-aws/v"$KARPENTER_VERSION"/website/content/en/preview/getting-started/getting-started-with-karpenter/cloudformation.yaml  > "$TEMPOUT" \
&& aws cloudformation deploy \
--stack-name "Karpenter-$CLUSTER_NAME" \
--template-file "$TEMPOUT" \
--capabilities CAPABILITY_NAMED_IAM \
--parameter-overrides "ClusterName=$CLUSTER_NAME"

eksctl utils associate-iam-oidc-provider --cluster $CLUSTER_NAME --approve

eksctl create iamserviceaccount \
--cluster "$CLUSTER_NAME" --name karpenter --namespace $KARPENTER_NAMESPACE \
--role-name "$CLUSTER_NAME-karpenter" \
--attach-policy-arn "arn:aws:iam::$AWS_ACCOUNT_ID:policy/KarpenterControllerPolicy-$CLUSTER_NAME" \
--role-only \
--approve
export KARPENTER_IAM_ROLE_ARN="arn:aws:iam::$AWS_ACCOUNT_ID:role/$CLUSTER_NAME-karpenter"

aws iam create-service-linked-role --aws-service-name spot.amazonaws.com || true

helm registry logout public.ecr.aws
helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter --version "$KARPENTER_VERSION" \
--namespace "$KARPENTER_NAMESPACE" --create-namespace \
--set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$KARPENTER_IAM_ROLE_ARN \
--set settings.clusterName=$CLUSTER_NAME \
--set settings.clusterEndpoint=$CLUSTER_ENDPOINT \
--set settings.featureGates.spotToSpotConsolidation=true \
--set settings.interruptionQueue=$CLUSTER_NAME \
--set controller.resources.requests.cpu=1 \
--set controller.resources.requests.memory=1Gi \
--set controller.resources.limits.cpu=1 \
--set controller.resources.limits.memory=1Gi \
--wait

wget -O eks-node-viewer https://github.com/awslabs/eks-node-viewer/releases/download/v0.7.1/eks-node-viewer_Linux_x86_64
chmod +x eks-node-viewer
sudo mv -v eks-node-viewer /usr/local/bin