terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Get current AWS account and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Networking module
module "networking" {
  source = "./modules/networking"

  vpc_name              = "ip-exhaustion-demo"
  vpc_cidr              = "192.168.16.0/26"
  secondary_cidr_blocks = var.phase >= 2 ? ["100.64.0.0/16"] : []
  public_subnet_cidrs   = ["192.168.16.0/28", "192.168.16.16/28"]
  private_subnet_cidrs  = ["192.168.16.32/28", "192.168.16.48/28"]
  pod_subnet_cidrs      = var.phase >= 2 ? ["100.64.0.0/20", "100.64.16.0/20"] : []
  large_node_subnet_cidrs = var.large_node_subnet_cidrs
  availability_zones    = slice(data.aws_availability_zones.available.names, 0, var.az_count)
  aws_region           = var.aws_region
  phase                = var.phase
  cluster_name         = var.cluster_name
  common_tags          = var.common_tags
}

# EKS module (without node groups for Auto Mode)
module "eks" {
  source = "./modules/eks"

  # Common variables
  cluster_name                = var.cluster_name
  cluster_version             = var.cluster_version
  aws_region                  = var.aws_region
  
  # Networking
  vpc_id                      = module.networking.vpc_id
  private_subnet_ids          = module.networking.private_subnet_ids
  pod_subnet_ids             = module.networking.pod_subnet_ids

  
  # Phase-specific
  phase                       = var.phase
  
  # Tags
  common_tags                 = var.common_tags
}



 