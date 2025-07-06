# AWS Configuration
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-north-1"
}

variable "az_count" {
  description = "Number of availability zones to use"
  type        = number
  default     = 2
}

# VPC Configuration - AWS Blog Architecture
variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
  default     = "ip-exhaustion-demo"
}

variable "vpc_cidr" {
  description = "Primary VPC CIDR block (routable range)"
  type        = string
  default     = "192.168.16.0/26"  # Much smaller: 64 IPs total for quick exhaustion
}

variable "secondary_cidr_blocks" {
  description = "Secondary CIDR blocks for Phase 2 (RFC 1918 private range)"
  type        = list(string)
  default     = ["172.32.0.0/16"]  # Standard private IP space (RFC 1918)
}

# Subnet Configuration - AWS Blog Architecture
variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (routable range)"
  type        = list(string)
  default     = ["192.168.16.0/28", "192.168.16.16/28"]  # 16 IPs each for quick exhaustion
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (routable range)"
  type        = list(string)
  default     = ["192.168.16.32/28", "192.168.16.48/28"]  # 16 IPs each for quick exhaustion
}

variable "pod_subnet_cidrs" {
  description = "CIDR blocks for pod subnets (Phase 2) - /20 blocks for worker nodes and pods"
  type        = list(string)
  default     = ["172.32.0.0/20", "172.32.16.0/20"]  # 4,096 IPs each (RFC 1918 compliant)
}

# EKS Configuration
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "ip-exhaustion-demo"
}

variable "cluster_version" {
  description = "EKS cluster version"
  type        = string
  default     = "1.33"
}

# Phase Configuration
variable "phase" {
  description = "Deployment phase (1 or 2)"
  type        = number
  default     = 1
  validation {
    condition     = contains([1, 2], var.phase)
    error_message = "Phase must be either 1 or 2."
  }
}

# Tags
variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "ip-exhaustion-demo"
    Environment = "demo"
    ManagedBy   = "terraform"
  }
}

variable "large_node_subnet_cidrs" {
  description = "CIDR blocks for large node subnets (dedicated, for high pod density)"
  type        = list(string)
  default     = [
    "172.32.64.0/24",   # 256 IPs (254 usable) - eu-central-1a
    "172.32.128.0/24"   # 256 IPs (254 usable) - eu-central-1b
  ]
} 