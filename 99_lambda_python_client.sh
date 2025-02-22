#!/bin/bash
# export aws_region=""
# export cluster_name=""
# echo "aws_region=''" >>/home/ec2-user/.bashrc
# echo "cluster_name=''" >>/home/ec2-user/.bashrc
source /home/ec2-user/.bashrc

# Kubernetes Python Client
# https://github.com/aws-samples/amazon-eks-kubernetes-api-aws-lambda
# https://aws.amazon.com/ko/blogs/opensource/simplifying-kubernetes-configurations-using-aws-lambda/
# https://aws.amazon.com/ko/blogs/opensource/a-container-free-way-to-configure-kubernetes-using-aws-lambda/
# https://docs.aws.amazon.com/ko_kr/step-functions/latest/dg/connect-eks.html

# install sam cli
# https://docs.aws.amazon.com/ko_kr/serverless-application-model/latest/developerguide/install-sam-cli.html
wget https://github.com/aws/aws-sam-cli/releases/latest/download/aws-sam-cli-linux-x86_64.zip
unzip aws-sam-cli-linux-x86_64.zip -d sam-installation
sudo ./sam-installation/install
rm -rf sam-installation aws-sam-cli-linux-x86_64.zip
sam --version

mkdir -p /home/ec2-user/lambda
mkdir -p /home/ec2-user/lambda/src

cat <<EOF > /home/ec2-user/lambda/template.yaml
AWSTemplateFormatVersion: '2010-09-09'
Transform: 'AWS::Serverless-2016-10-31'
Description: An AWS Lambda application that calls the EKS Kubernetes API.

# Parameters:
#   EksCluster:
#     Description: Name of the EKS cluster to monitor
#     Type: String

Resources:
  LambdaFunction:
    Type: AWS::Serverless::Function
    Properties:
      Environment:
        Variables:
          CLUSTER_NAME: $cluster_name
      Handler: kubernetes_client.handler
      Runtime: python3.12
      CodeUri: build/.
      Role: !GetAtt LambdaExecutionRole.Arn
      ReservedConcurrentExecutions: 5
      Timeout: 30
      MemorySize: 256

  LambdaExecutionRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service:
                - lambda.amazonaws.com
            Action:
              - sts:AssumeRole
      Path: /
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
      Policies:
        - PolicyName: EksClusterAdminPolicy
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - eks:*
                Resource: !Sub 'arn:aws:eks:\${AWS::Region}:\${AWS::AccountId}:cluster/$cluster_name'
  EksClusterAccessEntry:
    Type: AWS::EKS::AccessEntry
    Properties:
      AccessPolicies: 
        - AccessScope: 
            Type: cluster
          PolicyArn: arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy
      ClusterName: $cluster_name
      PrincipalArn: !GetAtt LambdaExecutionRole.Arn
      Type: STANDARD
EOF

cat <<EOF > /home/ec2-user/lambda/src/kubernetes_client.py
import base64
import os
import logging
import re
import boto3
from botocore.signers import RequestSigner
from kubernetes import client, config

logger = logging.getLogger()
logger.setLevel(logging.INFO)

STS_TOKEN_EXPIRES_IN = 60
session = boto3.session.Session()
sts = session.client('sts')
service_id = sts.meta.service_model.service_id
cluster_name = os.environ["CLUSTER_NAME"]
eks = boto3.client('eks')
cluster_cache = {}

def get_cluster_info():
    "Retrieve cluster endpoint and certificate"
    cluster_info = eks.describe_cluster(name=cluster_name)
    endpoint = cluster_info['cluster']['endpoint']
    cert_authority = cluster_info['cluster']['certificateAuthority']['data']
    cluster_info = {
        "endpoint" : endpoint,
        "ca" : cert_authority
    }
    return cluster_info

def get_bearer_token():
    "Create authentication token"
    signer = RequestSigner(
        service_id,
        session.region_name,
        'sts',
        'v4',
        session.get_credentials(),
        session.events
    )

    params = {
        'method': 'GET',
        'url': 'https://sts.{}.amazonaws.com/'
               '?Action=GetCallerIdentity&Version=2011-06-15'.format(session.region_name),
        'body': {},
        'headers': {
            'x-k8s-aws-id': cluster_name
        },
        'context': {}
    }

    signed_url = signer.generate_presigned_url(
        params,
        region_name=session.region_name,
        expires_in=STS_TOKEN_EXPIRES_IN,
        operation_name=''
    )
    base64_url = base64.urlsafe_b64encode(signed_url.encode('utf-8')).decode('utf-8')

    # remove any base64 encoding padding:
    return 'k8s-aws-v1.' + re.sub(r'=*', '', base64_url)


def handler(_event, _context):
    if cluster_name in cluster_cache:
        cluster = cluster_cache[cluster_name]
    else:
        # not present in cache retrieve cluster info from EKS service
        cluster = get_cluster_info()
        # store in cache for execution environment resuse
        cluster_cache[cluster_name] = cluster

    kubeconfig = {
        'apiVersion': 'v1',
        'clusters': [{
          'name': 'cluster1',
          'cluster': {
            'certificate-authority-data': cluster["ca"],
            'server': cluster["endpoint"]}
        }],
        'contexts': [{'name': 'context1', 'context': {'cluster': 'cluster1', "user": "user1"}}],
        'current-context': 'context1',
        'kind': 'Config',
        'preferences': {},
        'users': [{'name': 'user1', "user" : {'token': get_bearer_token()}}]
    }

    config.load_kube_config_from_dict(config_dict=kubeconfig)
    v1_api = client.CoreV1Api() # api_client
    ret = v1_api.list_namespaced_pod("default")
    return f"There are {len(ret.items)} pods in the default namespace."
EOF

cat <<EOF > /home/ec2-user/lambda/src/requirements.txt
kubernetes
EOF

# dnf update -y
# dnf install -y git
# dnf groupinstall -y "Development Tools"
# dnf install -y python3.12
# python3.12 -m ensurepip --upgrade
# python3.12 -m pip install --upgrade pip
# ln -s /usr/bin/pip3.12 /usr/local/bin/pip
# ln -s /usr/bin/python3.12 /usr/bin/python
# source ~/.bashrc

rm -rf /home/ec2-user/lambda/build
mkdir -p /home/ec2-user/lambda/build
cd /home/ec2-user/lambda/build
cp -r ../src/* .
pip install --platform=manylinux2014_x86_64 --only-binary=:all: -t . -r requirements.txt
cd ../
sam build
sam deploy --no-confirm-changeset --no-disable-rollback --capabilities CAPABILITY_NAMED_IAM --resolve-s3 --stack-name lambda-eks --region $aws_region
# sam delete --no-prompts --stack-name lambda-eks --region $aws_region