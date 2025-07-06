# VPC Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "vpc_cidr_block" {
  description = "Primary VPC CIDR block"
  value       = module.networking.vpc_cidr_block
}

output "secondary_cidr_blocks" {
  description = "Secondary CIDR blocks (Phase 2)"
  value       = module.networking.secondary_cidr_blocks
}

# AWS Region
output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

# Subnet Outputs
output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.networking.private_subnet_ids
}

output "pod_subnet_ids" {
  description = "Pod subnet IDs (Phase 2)"
  value       = module.networking.pod_subnet_ids
}

# EKS Outputs
output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "EKS cluster certificate authority data"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_oidc_issuer_url" {
  description = "EKS cluster OIDC issuer URL"
  value       = module.eks.cluster_oidc_issuer_url
}

output "cluster_oidc_provider_arn" {
  description = "EKS cluster OIDC provider ARN"
  value       = module.eks.cluster_oidc_provider_arn
}

output "cluster_role_arn" {
  description = "EKS cluster IAM role ARN"
  value       = module.eks.cluster_role_arn
}

output "node_role_arn" {
  description = "EKS node IAM role ARN"
  value       = module.eks.node_role_arn
}

# NAT Gateway Outputs
output "nat_gateway_ids" {
  description = "NAT Gateway IDs"
  value       = module.networking.nat_gateway_ids
}

# Route Table Outputs
output "private_route_table_ids" {
  description = "Private route table IDs"
  value       = module.networking.private_route_table_ids
}

# Security Group Outputs
output "cluster_security_group_id" {
  description = "EKS cluster security group ID"
  value       = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  description = "EKS node security group ID"
  value       = module.eks.node_security_group_id
}

# Phase Information
output "phase" {
  description = "Current deployment phase"
  value       = var.phase
}

output "phase_description" {
  description = "Description of current phase"
  value = var.phase == 1 ? "IPv4 Exhaustion Demo - Limited IPs" : "IPv4 Exhaustion Solution - Secondary CIDR"
}

# Connection Information
output "kubeconfig_command" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${var.cluster_name}"
}

output "test_commands" {
  description = "Commands to test the demo"
  value = {
    phase1_exhaustion = "kubectl scale deployment podinfo --replicas=50"
    phase2_solution   = "kubectl scale deployment podinfo --replicas=100"
    check_pods        = "kubectl get pods -o wide"
    check_nodes       = "kubectl get nodes"
  }
}

# IP Information
output "ip_summary" {
  description = "IP address summary"
  value = var.phase == 1 ? {
    total_ips        = 64
    usable_ips       = 32
    public_subnets   = "16 IPs each (10.0.0.0/28, 10.0.0.16/28)"
    private_subnets  = "16 IPs each (10.0.0.32/28, 10.0.0.48/28)"
    description      = "Limited IPs for exhaustion demonstration"
  } : {
    total_ips        = 8192
    usable_ips       = 8000
    public_subnets   = "16 IPs each (10.0.0.0/28, 10.0.0.16/28)"
    private_subnets  = "16 IPs each (10.0.0.32/28, 10.0.0.48/28)"
    pod_subnets      = "4,096 IPs each (100.64.0.0/20, 100.64.16.0/20)"
    description      = "Large IP pools with secondary CIDR"
  }
}

output "large_node_subnet_ids" {
  description = "Large node subnet IDs"
  value       = module.networking.large_node_subnet_ids
} 