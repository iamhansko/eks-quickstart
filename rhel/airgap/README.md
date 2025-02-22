# RHEL EKS Optimized AMI Builder (Airgap)

### EKS Setting
#### Node Security Group
- Add "`eks-cluster-sg-CLUSTER_NAME`"
#### Node IAM Role
- **`AmazonEC2ContainerRegistryReadOnly`**
- **`AmazonEKS_CNI_Policy`**
- **`AmazonEKSWorkerNodePolicy`**
- `AmazonSSMManagedInstanceCore` (Optional)
- `AmazonEBSCSIDriverPolicy` (Optional)
- `AmazonEFSCSIDriverPolicy` (Optional)
- `CloudWatchAgentServerPolicy` (Optional)
#### Node IAM Access Entry
- IAM principal : Node IAM Role
- Type : EC2 Linux
---

### How To

```bash
# Run a new EC2 Instance (RHEL based)
# Example : RHEL-8.10.0_HVM-20241031-x86_64-1584-Hourly2-GP3(ami-0294d1c0c9cd9d77c)

git clone https://github.com/iamhansko/eks-quickstart.git
cd eks-quickstart/rhel/airgap
chmod +x pre_build_ami.sh build_ami.sh

# Internet Access Enabled
# Set ENV (https://github.com/aws-samples/amazon-eks-ami-rhel/blob/main/doc/usage/rhel.md)
./pre_build_ami.sh

# Airgap
# Set ENV (https://github.com/aws-samples/amazon-eks-ami-rhel/blob/main/doc/usage/rhel.md)
./build_ami.sh
```
---
#### ( FIPS 및 EFA 옵션 비활성화 가정, ap-northeast-2 기준 )
#### [ 패키지 (Packages) ]
- kernel
- kernel-core
- kernel-modules
- grub2-tools-efi
- chrony
- conntrack
- ethtool
- ipvsadm
- jq
- nfs-utils
- python3
- socat
- unzip
- wget
- mdadm
- pigz
- iptables
- runc
- criu
- libnet
- protobuf-c
- container-selinux
- device-mapper-persistent-data
- lvm2
- lvm2-libs
- device-mapper-event
- device-mapper-event-libs
- libaio
- [amazon-ssm-agent](https://docs.aws.amazon.com/ko_kr/systems-manager/latest/userguide/agent-install-rhel.html)

#### [ AWS CLI (ECR 및 S3 접근 필요) ]
- [awscli](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

#### [ 컨테이너 런타임 및 CLI (Runtime & CLI) ]
- [containerd](https://github.com/containerd/containerd/releases)
- [nerdctl](https://github.com/containerd/nerdctl/releases)

#### [ 컨테이너 이미지 (Images) (nerdctl pull) ]
- nodeadm-builder : public.ecr.aws/eks-distro-build-tooling/golang:1.23
- pause : [602401143452.dkr.ecr.ap-northeast-2.amazonaws.com](https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/add-ons-images.html)/eks/pause:3.10

#### [ VPC 엔드포인트 (Endpoints) ]
- com.amazonaws.ap-northeast-2.sts
- com.amazonaws.ap-northeast-2.ec2
- com.amazonaws.ap-northeast-2.ecr.api
- com.amazonaws.ap-northeast-2.ecr.dkr
- com.amazonaws.ap-northeast-2.s3 ([using private binary bucket](https://github.com/aws-samples/amazon-eks-ami-rhel/blob/main/doc/usage/overview.md#providing-your-own))

#### [ S3 바이너리 (Binaries) ]
([using private binary bucket](https://github.com/aws-samples/amazon-eks-ami-rhel/blob/main/doc/usage/overview.md#providing-your-own))
```bash
BINARY_BUCKET_REGION="ap-northeast-2"
BINARY_BUCKET_NAME="amazon-eks"
KUBERNETES_VERSION="1.31.4"
KUBERNETES_BUILD_DATE="2025-01-10"
ARCH="amd64"
S3_PATH="s3://$BINARY_BUCKET_NAME/$KUBERNETES_VERSION/$KUBERNETES_BUILD_DATE/bin/linux/$ARCH"
aws s3 cp --region $BINARY_BUCKET_REGION $S3_PATH/kubelet ./amazon-eks-ami-rhel
aws s3 cp --region $BINARY_BUCKET_REGION $S3_PATH/kubelet.sha256 ./amazon-eks-ami-rhel
aws s3 cp --region $BINARY_BUCKET_REGION $S3_PATH/ecr-credential-provider ./amazon-eks-ami-rhel
```