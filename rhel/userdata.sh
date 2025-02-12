MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="//"

--//
Content-Type: application/node.eks.aws

---
apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
spec:
  cluster:
    name: # cluster name
    apiServerEndpoint: # api server endpoint (ex https://XXXXXXXXXXXXX.XXX.XXXXXXXXXX.eks.amazonaws.com)
    certificateAuthority: # cluster certificate authority
    cidr: # service ipv4 range (ex 172.20.0.0/16) 
  kubelet:
    config:
      shutdownGracePeriod: 30s
      featureGates:
        DisableKubeletCloudCredentialProviders: true
  containerd:
    config: |
      [plugins."io.containerd.grpc.v1.cri".containerd]
      discard_unpacked_layers = false

--//
Content-Type: text/x-shellscript; charset="us-ascii"

#!/bin/bash

# https://github.com/aws-samples/amazon-eks-ami-rhel/issues/2
systemctl stop nm-cloud-setup.timer
systemctl disable nm-cloud-setup.timer
systemctl stop nm-cloud-setup.service
systemctl disable nm-cloud-setup.service

--//--