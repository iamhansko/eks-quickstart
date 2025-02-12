# RHEL EKS Optimized AMI Builder

```bash
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