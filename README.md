# 🚀 IPv4 Exhaustion: From 32 to 8,000+ Pods in Minutes!

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Terraform](https://img.shields.io/badge/Terraform-1.0+-blue.svg)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-EKS-orange.svg)](https://aws.amazon.com/eks/)

This project demonstrates the challenge of IPv4 address exhaustion in Amazon EKS clusters and how to solve it using advanced VPC networking and EKS Auto Mode.

## Problem Overview

Modern Kubernetes clusters running on AWS EKS can quickly run out of available IPv4 addresses, especially when using small VPC CIDR blocks. This leads to:
- Pods stuck in Pending state due to lack of IPs
- Application scaling failures
- Service disruptions and wasted resources

## Solution Overview

This demo shows how to:
- Identify and reproduce IPv4 exhaustion in a real EKS environment
- Seamlessly scale to thousands of pods by adding a secondary, non-routable CIDR block to your VPC
- Use dedicated subnets for nodes and pods, with EKS Auto Mode for automated node management
- Achieve zero-downtime upgrades and avoid cluster migrations

## How to Run

1. **Initialize Terraform**
   ```bash
   terraform init
   ```

2. **Deploy Phase 1 (Exhaustion Demo)**
   ```bash
   terraform apply -var="phase=1"
   ```

3. **Access the Cluster**
   ```bash
   aws eks update-kubeconfig --region <region> --name <cluster-name>
   kubectl get nodes
   kubectl get pods -o wide
   ```

4. **Apply NodeClass, NodePool, and Demo Apps (see them apps struggle)**
   ```bash
   kubectl apply -f examples/phase1/nodeclass.yaml
   kubectl apply -f examples/phase1/nodepool.yaml
   kubectl apply -f examples/phase1/demo-app.yaml
   kubectl apply -f examples/phase1/general-demo.yaml
   ```

5. **Upgrade to Phase 2 (Solution)**
   ```bash
   terraform apply -var="phase=2"
   ```

## Learn More

For a detailed technical breakdown of the architecture and implementation, see:

👉 [ARCHITECTURE.md](./ARCHITECTURE.md)

## References

- [AWS IPv4 Exhaustion Blog](https://aws.amazon.com/blogs/containers/amazon-eks-supports-ipv6/)
- [AWS Enhanced Subnet Discovery](https://aws.amazon.com/blogs/containers/amazon-eks-enhanced-subnet-discovery/)
- [AWS EKS Auto Mode Documentation](https://docs.aws.amazon.com/eks/latest/userguide/create-node-class.html#pod-subnet-selector)
- [RFC 6598 - Shared Address Space](https://tools.ietf.org/html/rfc6598) 