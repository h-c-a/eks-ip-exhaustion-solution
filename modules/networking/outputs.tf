# VPC Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "Primary VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "secondary_cidr_blocks" {
  description = "Secondary CIDR blocks"
  value       = aws_vpc_ipv4_cidr_block_association.secondary[*].cidr_block
}

# Subnet Outputs
output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "pod_subnet_ids" {
  description = "Pod subnet IDs (Phase 2)"
  value       = aws_subnet.pod_phase2[*].id
}



output "large_node_subnet_ids" {
  description = "Large node subnet IDs (dedicated, high pod density)"
  value       = aws_subnet.large_node[*].id
}

# NAT Gateway Outputs
output "nat_gateway_ids" {
  description = "NAT Gateway IDs"
  value       = aws_nat_gateway.main[*].id
}

# Route Table Outputs
output "private_route_table_ids" {
  description = "Private route table IDs"
  value       = aws_route_table.private[*].id
}

# Internet Gateway Output
output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.main.id
} 