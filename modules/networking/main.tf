# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.common_tags, {
    Name = "ip-exhaustion-demo"
  })
}

# Secondary CIDR blocks (Phase 2)
resource "aws_vpc_ipv4_cidr_block_association" "secondary" {
  count = var.phase >= 2 ? length(var.secondary_cidr_blocks) : 0

  vpc_id     = aws_vpc.main.id
  cidr_block = var.secondary_cidr_blocks[count.index]
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, {
    Name = "ip-exhaustion-demo-igw"
  })
}

# Public Subnets
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.common_tags, {
    Name = "ip-exhaustion-demo-public-${var.availability_zones[count.index]}"
    "kubernetes.io/role/elb" = "1"
  })
}

# Private Subnets (for EKS-managed ENIs - /28 blocks)
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.common_tags, {
    Name = "ip-exhaustion-demo-node-small"
    "kubernetes.io/role/internal-elb" = "1"
    Environment = "demo"
    Component = "eks-nodes"
    Purpose = "node-subnet"
  })
}

# Pod Subnets (Phase 2 - /20 blocks for worker nodes and pods)
resource "aws_subnet" "pod_phase2" {
  count = var.phase >= 2 ? length(var.pod_subnet_cidrs) : 0

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.pod_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.common_tags, {
    Name = "ip-exhaustion-demo-pod-large"
    "kubernetes.io/role/pod" = "1"
    "kubernetes.io/role/internal-elb" = "1"
    Environment = "demo"
    Component = "eks-pods"
    Purpose = "pod-subnet"
  })

  depends_on = [aws_vpc_ipv4_cidr_block_association.secondary]
}



# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count = length(var.availability_zones)

  domain = "vpc"

  tags = merge(var.common_tags, {
    Name = "ip-exhaustion-demo-nat-eip-${var.availability_zones[count.index]}"
  })
}

# NAT Gateways
resource "aws_nat_gateway" "main" {
  count = length(var.availability_zones)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.common_tags, {
    Name = "ip-exhaustion-demo-nat-${var.availability_zones[count.index]}"
  })

  depends_on = [aws_internet_gateway.main]
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.common_tags, {
    Name = "ip-exhaustion-demo-public-rt"
  })
}

# Public Route Table Associations
resource "aws_route_table_association" "public" {
  count = length(var.public_subnet_cidrs)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Route Tables
resource "aws_route_table" "private" {
  count = length(var.availability_zones)

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge(var.common_tags, {
    Name = "ip-exhaustion-demo-node-route-table"
    Purpose = "node-routing"
  })
}

# Private Route Table Associations
resource "aws_route_table_association" "private" {
  count = length(var.private_subnet_cidrs)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Pod Route Tables (Phase 2)
resource "aws_route_table" "pod" {
  count = var.phase >= 2 ? length(var.availability_zones) : 0

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge(var.common_tags, {
    Name = "ip-exhaustion-demo-pod-route-table"
    Purpose = "pod-routing"
  })
}

# Pod Route Table Associations (Phase 2)
resource "aws_route_table_association" "pod" {
  count = var.phase >= 2 ? length(var.pod_subnet_cidrs) : 0

  subnet_id      = aws_subnet.pod_phase2[count.index].id
  route_table_id = aws_route_table.pod[count.index].id
}

# Large Node Subnets (dedicated, high pod density)
resource "aws_subnet" "large_node" {
  count = var.phase >= 2 ? length(var.large_node_subnet_cidrs) : 0

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.large_node_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.common_tags, {
    Name = "ip-exhaustion-demo-node-large"
    "kubernetes.io/role/internal-elb" = "1"
    Environment = "demo"
    Component = "eks-nodes-large"
    Purpose = "dedicated-node-subnet"
  })

  depends_on = [aws_vpc_ipv4_cidr_block_association.secondary]
}

# Large Node Route Table Associations
resource "aws_route_table_association" "large_node" {
  count = var.phase >= 2 ? length(var.large_node_subnet_cidrs) : 0

  subnet_id      = aws_subnet.large_node[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Security Group Requirements for EKS Auto Mode
# 
# The EKS module creates security groups for the cluster and nodes, but requires
# proper inbound rules to allow node-to-cluster communication:
#
# 1. Cluster Security Group (aws_security_group.cluster):
#    - Inbound rule: Port 443 from Node Security Group (API server)
#    - Inbound rule: Ports 1025-65535 from Node Security Group (other services)
#    - Inbound rule: All traffic within cluster security group (self)
#
# 2. Node Security Group (aws_security_group.node):
#    - Outbound rule: Port 443 to Cluster Security Group
#    - Outbound rule: Ports 1025-65535 to Cluster Security Group
#    - Outbound rule: All traffic to internet (0.0.0.0/0)
#
# These rules are now configured in the EKS module to prevent node registration
# failures due to network connectivity issues. 