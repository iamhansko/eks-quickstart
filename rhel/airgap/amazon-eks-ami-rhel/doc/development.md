# Development

## Writing documentation

GitHub Pages serves a static site generated by `mkdoc`. A wrapper for `mkdoc` is provided by `hack/mkdoc.sh`.

To serve the site locally, run:
```
hack/mkdocs.sh serve
```

---

## Generating max pod values

By default, the maximum number of pods able to be scheduled on a node is based off of the number of ENIs
available, which is determined by the instance type. Larger instances generally have more ENIs. The
number of ENIs limits how many IPV4 addresses are available on an instance, and we need one IP address
per pod. You can [see this file](https://github.com/aws/amazon-vpc-cni-k8s/blob/master/scripts/gen_vpc_ip_limits.go)
for the code that calculates the max pods for more information.

As an optimization, the default value for all known instance types are available in a resource file
(`eni-max-pods.txt`) in the AMI. If an instance type is not found in this file, the
`ec2:DescribeInstanceTypes` API is used to calculate the value at runtime.

The resource file is generated once per day by a GitHub Action workflow.

To generate the resource file:
```
git clone git@github.com:aws/amazon-vpc-cni-k8s.git
cd amazon-vpc-cni-k8s/
make generate-limits
cp misc/eni-max-pods.txt ../amazon-eks-ami-rhel/templates/shared/runtime/
```
