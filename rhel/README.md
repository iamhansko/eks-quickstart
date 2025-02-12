# RHEL EKS Optimized AMI Builder

```bash
git clone https://github.com/iamhansko/eks-quickstart.git

# Create a new IAM Role "BuilderEc2IamRole"
# IAM Policy (json)
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AmiBuilder",
      "Effect": "Allow",
      "Action": [
          "ec2:CreateImage",
          "s3:Get*",
          "s3:List*",
          "s3:Describe*",
          "s3-object-lambda:Get*",
          "s3-object-lambda:List*",
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchGetImage",
          "ecr:GetLifecyclePolicy",
          "ecr:GetLifecyclePolicyPreview",
          "ecr:ListTagsForResource",
          "ecr:DescribeImageScanFindings"
      ],
      "Resource": "*"
    }
  ]
}

# Example
make k8s=1.31\
 source_ami_filter_name=RHEL-8.10.0_HVM-20241031-x86_64-*\
 aws_region=ap-northeast-2\
 ami_regions=ap-northeast-2\
 binary_bucket_region=ap-northeast-2\
 containerd_version=1.7.24\
 pause_container_image=602401143452.dkr.ecr.ap-northeast-2.amazonaws.com/eks/pause:3.10\
 iam_instance_profile=BuilderEc2IamRole
```