# Addressing IPv4 address exhaustion in Amazon EKS clusters with EKS Auto Mode and secondary CIDR blocks

by [Your Name] on [Date] in Amazon Elastic Kubernetes Service, Amazon VPC, Containers, Technical How-to

## Introduction

The Amazon VPC Container Network Interface (CNI) plugin provides significant advantages for pod networking when deployed on Amazon Elastic Kubernetes Service (Amazon EKS) clusters. It enables you to leverage proven, battle-tested Amazon Virtual Private Cloud (Amazon VPC) networking and security best practices for building Kubernetes clusters on AWS. This allows you to use VPC flow logs for troubleshooting and compliance auditing, apply VPC routing policies for traffic engineering, and apply security groups to enforce isolation and meet regulatory requirements. You get the raw performance of Amazon EC2 networking, with no additional overlay.

By default, the Amazon VPC CNI plugin assigns each pod a routable IPv4 address from the VPC CIDR block, treating each pod as a first-class citizen in the VPC. This enables network communication between resources in various scenarios: pod-to-pod on a single host, pod-to-pod on different hosts, pod-to-other AWS services, pod-to-on-premises data centers, and pod-to-internet.

Customers typically use RFC1918 private IPv4 address ranges to set up Amazon VPCs for their workloads. In large organizations, it's common for operations teams within business units to set up separate, dedicated VPCs to meet their specific needs. When these private networks need to communicate with other networks—either on-premises or in other VPCs—they must ensure non-overlapping CIDR ranges. As a result, teams are often forced to use relatively smaller CIDR ranges for their VPCs to avoid potential overlaps. When such teams use container orchestration platforms like Amazon EKS to deploy microservices architectures, they frequently launch hundreds or thousands of workloads (pods) in their clusters.

When pods are assigned IPv4 addresses from the VPC CIDR range, this often leads to exhaustion of the limited number of IPv4 addresses available in their VPCs.

This post shows you how to address IPv4 address exhaustion in Amazon EKS clusters using EKS Auto Mode and secondary CIDR blocks. You'll learn how to implement a zero-downtime solution that scales your cluster from supporting 32 pods to over 8,000 pods without recreating your infrastructure.

### Exploring IPv4 address exhaustion solutions

Custom pod networking is one approach to alleviate IPv4 address exhaustion when deploying large-scale workloads to an Amazon EKS cluster. It allows you to expand your VPCs by adding secondary IPv4 address ranges and then using these address ranges to assign IPv4 addresses to pods. Amazon recommends using CIDRs from the carrier grade-network address translation (CG-NAT) space (i.e., 100.64.0.0/10 or 198.19.0.0/16) because those are less likely to be used in a corporate setting than other RFC1918 ranges. However, this approach adds complexity to the cluster configuration, and there's no guarantee that using CG-NAT address space will completely eliminate the likelihood of overlapping networks.

If custom networking isn't viable, you may have to use a different CNI plugin that uses a non-routable overlay network to assign IPv4 addresses to pods, forgoing all the advantages of using Amazon VPC networking for pods in the cluster. The best long-term solution for the IPv4 exhaustion issue is to use IPv6. However, the decision to adopt IPv6 is typically made at the organization level rather than by operations teams within individual business units.

### The EKS Auto Mode solution

Amazon EKS Auto Mode simplifies cluster management by automatically handling node provisioning, scaling, and networking configuration. This new approach can be extended to work with secondary CIDR blocks to solve the IP exhaustion problem while maintaining the simplicity of Auto Mode. Auto Mode eliminates the need for separate ENI subnet configuration, as ENIs are created in the same subnet as nodes, simplifying the architecture compared to traditional EKS.

This post highlights the advantages of implementing a network architecture with secondary CIDR blocks and EKS Auto Mode to deploy an Amazon EKS cluster. We demonstrate a use case where workloads deployed in an Amazon EKS cluster provisioned with Auto Mode can scale to thousands of pods using secondary CIDR blocks without the complexity of traditional EKS networking.

## Solution overview

The network architecture used in this implementation follows the recommendations for secondary CIDR blocks in Amazon VPC documentation. The routable address range (address ranges that cannot overlap) chosen here is 192.168.16.0/26 and the non-routable address range (address ranges that can overlap) is 172.32.0.0/16.

Let's assume that an IP Address Management (IPAM) team has granted the routable address range 192.168.16.0/26 for setting up a VPC. The address range 172.32.0.0/16 is added as the secondary CIDR for this VPC. Subnets are set up across two Availability Zones (AZs). The following network diagram details various subnets in the VPC, which is set up using Terraform. Here are the salient aspects of this network architecture:

* Two private subnets, each with 16 IP addresses (/28 block) are set up in the routable range. These subnets are used for EKS cluster creation and node placement in Phase 1.
* Two large private subnets, each with 256 IP addresses (/24 block) are set up in the non-routable range for dedicated node placement in Phase 2. These subnets are used by EKS Auto Mode for node placement.
* Two large pod subnets, each with 4,096 IP addresses (/20 block) are set up in the non-routable range for pod placement in Phase 2. These subnets are used by EKS Auto Mode for pod placement.
* Two private subnets and two public subnets, each with 16 IP addresses (/28) are set up in the routable range for NAT gateways and internet connectivity.
* A NAT gateway is placed in the /28 routable public subnet in each AZ and is associated with an internet gateway to enable resources in the Amazon EKS cluster to access resources on the internet.
* To enable traffic routing as described previously, the route tables for the subnets are set up to route traffic through NAT gateways for outbound connectivity.

## Prerequisites

Before you begin, ensure you have the following:

* An AWS account with appropriate permissions to create VPCs, subnets, NAT gateways, and EKS clusters
* Terraform version 1.0 or later installed on your local machine
* kubectl configured to work with Amazon EKS clusters
* Basic understanding of Amazon VPC networking and Amazon EKS concepts

For this post, we are using Terraform 1.0+ and Amazon EKS version 1.33.

## EKS Auto Mode architecture

### Traditional EKS vs EKS Auto Mode

**Traditional EKS (Node Groups):**
- ENIs are created in separate ENI subnets specified in node group configuration
- ENIs get IP addresses from dedicated ENI subnets
- Cross-account ENIs use ENI subnets for IP allocation
- VPC CNI plugin configures ENI subnet IDs explicitly

**EKS Auto Mode (NodeClass):**
- No separate ENI subnet configuration in NodeClass
- ENIs are created in the same subnet as nodes
- ENIs get IP addresses from node subnets
- Simplified architecture with fewer subnet types

### NodeClass configuration

```yaml
apiVersion: eks.amazonaws.com/v1
kind: NodeClass
metadata:
  name: large-ip-pool-nodeclass
spec:
  # Node subnets (where nodes AND ENIs are placed)
  subnetSelectorTerms:
    - tags:
        Environment: "demo"
        Component: "eks-nodes-large"
        kubernetes.io/role/internal-elb: "1"
  
  # Pod subnets (where pods are placed)
  podSubnetSelectorTerms:
    - tags:
        Environment: "demo"
        Component: "eks-pods"
        kubernetes.io/role/pod: "1"
  
  # Security groups
  securityGroupSelectorTerms:
    - tags:
        Environment: "demo"
        Component: "eks-cluster"
```

### NodePool configuration

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: ip-exhaustion-demo-nodepool
spec:
  template:
    metadata:
      labels:
        Project: ip-exhaustion-demo
        Environment: demo
        NodeType: ip-exhaustion-demo-node
    spec:
      nodeClassRef:
        group: eks.amazonaws.com
        kind: NodeClass
        name: large-ip-pool-nodeclass
      requirements:
        - key: "karpenter.sh/capacity-type"
          operator: In
          values: ["on-demand"]
        - key: "eks.amazonaws.com/instance-category"
          operator: In
          values: ["c", "m", "r"]
        - key: "eks.amazonaws.com/instance-cpu"
          operator: In
          values: ["4", "8", "16"]
        - key: "kubernetes.io/arch"
          operator: In
          values: ["amd64"]
  limits:
    cpu: "1000"
    memory: 1000Gi
```

## Implementation

### Phase 1: IPv4 exhaustion demo

**Infrastructure:**
```
VPC: 192.168.16.0/26 (64 IPs total)
├── Public Subnets: 192.168.16.0/28, 192.168.16.16/28 (16 IPs each)
├── Private Subnets: 192.168.16.32/28, 192.168.16.48/28 (16 IPs each)
└── EKS Cluster: Uses private subnets for pods
```

**IP Allocation:**
- Total VPC IPs: 64
- Reserved IPs: ~32 (gateways, ENIs, and more)
- Usable for pods: ~32
- Per subnet: ~16 usable IPs

**Exhaustion Scenario:**
1. Deploy EKS cluster with 2 nodes
2. Each node uses ~8 IPs for system pods
3. Scale application to 50+ replicas
4. Pods stuck in Pending state
5. No more IPs available

### Phase 2: Solution implementation

**Infrastructure:**
```
VPC: 192.168.16.0/26 + 172.32.0.0/16 (Secondary)
├── Public Subnets: 192.168.16.0/28, 192.168.16.16/28
├── Private Subnets: 192.168.16.32/28, 192.168.16.48/28
├── Node Subnets: 172.32.64.0/24, 172.32.128.0/24 (256 IPs each)
├── Pod Subnets: 172.32.0.0/20, 172.32.16.0/20 (4,096 IPs each)
└── EKS Cluster: Uses dedicated node and pod subnets
```

**IP Allocation:**
- Primary VPC: 64 IPs (existing)
- Secondary CIDR: 65,536 IPs
- Node Subnets: 512 IPs (256 each) - for node placement
- Pod Subnets: 8,192 IPs (4,096 each) - for pod placement
- Usable for pods: 8,000+

**Solution Components:**
1. Secondary CIDR Block: `172.32.0.0/16`
2. Node Subnets: Dedicated /24 subnets for node placement
3. Pod Subnets: Large /20 subnets for pod placement
4. NAT Gateways: Outbound connectivity for pods
5. Route Tables: Direct traffic through NATs
6. EKS Auto Mode: Simplified node and pod management

## Network flow

**Phase 1: Limited connectivity**
```
Pod → Private Subnet → NAT Gateway → Internet Gateway → Internet
```

**Phase 2: Enhanced connectivity**
```
Pod → Pod Subnet → NAT Gateway → Internet Gateway → Internet
```

## Zero-downtime upgrade process

**Phase 1 to Phase 2 transition:**

### Update Terraform variables

1. Open your Terraform configuration file.
2. Change the phase variable from 1 to 2.
3. Run the following command:

```bash
terraform apply -var="phase=2"
```

### Apply infrastructure changes

Terraform automatically performs the following actions:
- Adds secondary CIDR block (`172.32.0.0/16`)
- Creates node subnets (`172.32.64.0/24`, `172.32.128.0/24`)
- Creates pod subnets (`172.32.0.0/20`, `172.32.16.0/20`)
- Configures route tables and NAT gateways
- Updates EKS cluster configuration

### Apply EKS Auto Mode

1. Apply the NodeClass configuration:

```bash
kubectl apply -f examples/phase1/nodeclass.yaml
```

2. Apply the NodePool configuration:

```bash
kubectl apply -f examples/phase1/nodepool.yaml
```

### Deploy demo application

1. Apply the demo application:

```bash
kubectl apply -f examples/phase1/demo-app.yaml
```

### Verify upgrade

1. Check node status:

```bash
kubectl get nodes
```

2. Check pod distribution:

```bash
kubectl get pods -o wide
```

## Clean up resources

To avoid incurring charges, delete the resources created during this procedure:

1. Delete the demo application:

```bash
kubectl delete -f examples/phase1/demo-app.yaml
```

2. Delete the NodePool and NodeClass:

```bash
kubectl delete -f examples/phase1/nodepool.yaml
kubectl delete -f examples/phase1/nodeclass.yaml
```

3. Destroy the Terraform infrastructure:

```bash
terraform destroy
```

**Note**: This will delete all resources created in this post, including the VPC, subnets, NAT gateways, and EKS cluster.

## Conclusion

In this post, we showed you a network design that addresses IPv4 address exhaustion for Amazon EKS customers using EKS Auto Mode and the Amazon VPC CNI plugin for pod networking. This architecture was enabled by secondary CIDR blocks that allowed compute resources to scale to thousands of pods while maintaining the simplicity of Auto Mode.

The key advantages of this approach include:
- **Zero-downtime upgrades** from limited IP ranges to large IP pools
- **Simplified architecture** with EKS Auto Mode eliminating ENI subnet complexity
- **Cost-effective scaling** without additional infrastructure costs
- **Production-ready solution** using RFC1918 private address space

For organizations looking to scale their EKS clusters to support thousands of pods while maintaining operational simplicity, EKS Auto Mode with secondary CIDR blocks provides an excellent solution that combines the benefits of traditional VPC networking with the ease of use of Auto Mode.

### Next steps

To learn more about this solution, review the following resources:

- [Amazon EKS Auto Mode documentation](https://docs.aws.amazon.com/eks/latest/userguide/create-node-class.html)
- [Amazon VPC CNI plugin documentation](https://github.com/aws/amazon-vpc-cni-k8s)
- [Secondary CIDR blocks in Amazon VPC](https://docs.aws.amazon.com/vpc/latest/userguide/working-with-vpcs.html#add-ipv4-cidr)

For more information about IPv4 exhaustion solutions, refer to [Addressing IPv4 address exhaustion in Amazon EKS clusters using private NAT gateways](https://aws.amazon.com/blogs/containers/addressing-ipv4-address-exhaustion-in-amazon-eks-clusters-using-private-nat-gateways/).

## References

- [AWS IPv4 Exhaustion Blog](https://aws.amazon.com/blogs/containers/amazon-eks-supports-ipv6/)
- [AWS Enhanced Subnet Discovery](https://aws.amazon.com/blogs/containers/amazon-eks-enhanced-subnet-discovery/)
- [EKS Auto Mode Documentation](https://docs.aws.amazon.com/eks/latest/userguide/create-node-class.html)
- [RFC 1918 - Private Address Space](https://tools.ietf.org/html/rfc1918)
- [AWS VPC CNI Documentation](https://github.com/aws/amazon-vpc-cni-k8s)

## About the author

[Your Name] is a Solutions Architect at AWS, specializing in container technologies and networking. [Your brief bio here]. 