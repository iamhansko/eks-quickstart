#!/bin/bash

CLUSTER_NAME=hans
REGION=us-east-1
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

eksctl utils associate-iam-oidc-provider --cluster $CLUSTER_NAME --region $REGION --approve

S3_BUCKET_NAME="iamhanskos3csibucket"

aws s3 mb s3://$S3_BUCKET_NAME

cat << EOF > iam_policy.json
{
   "Version": "2012-10-17",
   "Statement": [
        {
            "Sid": "MountpointFullBucketAccess",
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::$S3_BUCKET_NAME"
            ]
        },
        {
            "Sid": "MountpointFullObjectAccess",
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:AbortMultipartUpload",
                "s3:DeleteObject"
            ],
            "Resource": [
                "arn:aws:s3:::$S3_BUCKET_NAME/*"
            ]
        }
   ]
}
EOF

aws iam create-policy \
--policy-name AmazonEKS_S3_CSI_DriverPolicy \
--policy-document file://iam_policy.json

rm iam_policy.json

POLICY_ARN="arn:aws:iam::$ACCOUNT_ID:policy/AmazonEKS_S3_CSI_DriverPolicy"

ROLE_NAME=AmazonEKS_S3_CSI_DriverRole

eksctl create iamserviceaccount \
--name s3-csi-driver-sa \
--namespace kube-system \
--cluster $CLUSTER_NAME \
--attach-policy-arn $POLICY_ARN \
--approve \
--role-name $ROLE_NAME \
--region $REGION \
--role-only

aws configure set region $REGION

eksctl create addon --name aws-mountpoint-s3-csi-driver --cluster $CLUSTER_NAME \
--service-account-role-arn arn:aws:iam::$ACCOUNT_ID:role/AmazonEKS_S3_CSI_DriverRole --force