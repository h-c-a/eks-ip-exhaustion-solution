# IPv4 Exhaustion Demo Architecture

This demo shows IPv4 address exhaustion in EKS clusters and the solution using secondary CIDR blocks.

## Problem: IPv4 Exhaustion

**What happens:**
- Small VPC CIDR (e.g., /26 = 64 IPs) provides limited addresses
- IPs reserved for gateways, ENIs, system pods
- Pods get stuck in Pending state when IPs exhausted
- Application scaling fails

**Impact:**
- Pods stuck in Pending state
- Horizontal Pod Autoscaler failures
- Service disruptions
- Resource waste (CPU/memory available but no IPs)

## Solution: Secondary CIDR Blocks

**AWS Secondary CIDR Feature:**
- Add IP ranges without recreating VPC
- Use non-routable space for pods
- Zero-downtime upgrade
- Scale to thousands of pods

**Private Address Space:**
- Use `172.32.0.0/16` (RFC 1918 Private Address Space)
- Standard private IP range (not routable on internet)
- 65,536 IP addresses available
- AWS supported and security-tool friendly

## Phase 1: IPv4 Exhaustion Demo

**Infrastructure:**
```
VPC: 10.0.0.0/26 (64 IPs total)
├── Public Subnets: 10.0.0.0/28, 10.0.0.16/28 (16 IPs each)
├── Private Subnets: 10.0.0.32/28, 10.0.0.48/28 (16 IPs each)
└── EKS Cluster: Uses private subnets for pods
```

**IP Allocation:**
- Total VPC IPs: 64
- Reserved IPs: ~32 (gateways, ENIs, etc.)
- Usable for pods: ~32
- Per subnet: ~16 usable IPs

**Exhaustion Scenario:**
1. Deploy EKS cluster with 2 nodes
2. Each node uses ~8 IPs for system pods
3. Scale application to 50+ replicas
4. Pods stuck in Pending state
5. No more IPs available

## Phase 2: Solution Implementation

**Infrastructure:**
```
VPC: 10.0.0.0/26 + 172.32.0.0/16 (Secondary)
├── Public Subnets: 10.0.0.0/28, 10.0.0.16/28
├── Private Subnets: 10.0.0.32/28, 10.0.0.48/28
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

5. Private NAT Gateways: Outbound connectivity for pods
6. Route Tables: Direct traffic through private NATs
7. EKS Configuration: Updated to use dedicated subnets

## Network Flow

**Phase 1: Limited Connectivity**
```
Pod → Private Subnet → NAT Gateway → Internet Gateway → Internet
```

**Phase 2: Enhanced Connectivity**
```
Pod → Pod Subnet → Private NAT Gateway → NAT Gateway → Internet Gateway → Internet
```

## EKS Auto Mode Architecture

**Note:** ENI subnets are not used in EKS Auto Mode. ENIs are created in the same subnet as nodes, simplifying the architecture compared to traditional EKS.

**NodeClass Configuration:**
```yaml
apiVersion: eks.amazonaws.com/v1
kind: NodeClass
metadata:
  name: large-ip-pool-nodeclass
spec:
  # Node subnets (where nodes are placed)
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

**NodePool Configuration:**
```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: ip-exhaustion-demo-nodepool
spec:
  template:
    spec:
      nodeClassRef:
        name: large-ip-pool-nodeclass
      requirements:
        - key: "karpenter.sh/capacity-type"
          operator: In
          values: ["on-demand"]
```

**Application Deployment:**
```yaml
spec:
  template:
    spec:
      nodeSelector:
        eks.amazonaws.com/nodeclass: large-ip-pool-nodeclass
```

## Zero-Downtime Upgrade Process

**Phase 1 to Phase 2 Transition:**

1. **Update Terraform Variables:**
   ```bash
   terraform apply -var="phase=2"
   ```

2. **Terraform Automatically:**
   - Adds secondary CIDR block (`172.32.0.0/16`)
   - Creates node subnets (`172.32.64.0/24`, `172.32.128.0/24`)
   - Creates pod subnets (`172.32.0.0/20`, `172.32.16.0/20`)

   - Configures route tables and NAT gateways
   - Updates EKS cluster configuration

3. **Apply EKS Auto Mode:**
   ```bash
   ./scripts/setup-auto-mode.sh
   ```

4. **Verify Upgrade:**
   ```bash
   kubectl get nodes
   kubectl get pods -o wide
   ```

## Cost Analysis

**Phase 1 (Exhaustion):**
- **Internet Gateway**: Standard pricing
- **NAT Gateway**: Per AZ
- **EKS Cluster**: Standard pricing
- **EC2 Nodes**: Based on instance types and count
- **VPC and Subnets**: Standard networking costs

**Phase 2 (Solution):**
- **Internet Gateway**: Same as Phase 1
- **NAT Gateway**: Same as Phase 1
- **EKS Cluster**: Same as Phase 1
- **EC2 Nodes**: Same as Phase 1
- **VPC and Subnets**: Same as Phase 1
- **Secondary CIDR**: No additional cost

**Cost Impact:**
- **Additional Components**: Extra NAT Gateway for pod subnets
- **Benefit**: Support for 8,000+ pods vs 32 pods
- **ROI**: Avoids cluster recreation costs
- **Operational Savings**: Zero downtime vs potential service disruption

## References

- [AWS IPv4 Exhaustion Blog](https://aws.amazon.com/blogs/containers/amazon-eks-supports-ipv6/)
- [AWS Enhanced Subnet Discovery](https://aws.amazon.com/blogs/containers/amazon-eks-enhanced-subnet-discovery/)
- [RFC 6598 - Shared Address Space](https://tools.ietf.org/html/rfc6598)
- [AWS VPC CNI Documentation](https://github.com/aws/amazon-vpc-cni-k8s)
- [EKS Best Practices](https://docs.aws.amazon.com/eks/latest/userguide/best-practices.html) 