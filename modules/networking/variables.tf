# VPC Configuration
variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "Primary VPC CIDR block"
  type        = string
}

variable "secondary_cidr_blocks" {
  description = "Secondary CIDR blocks for Phase 2"
  type        = list(string)
  default     = []
}

# Subnet Configuration
variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

variable "pod_subnet_cidrs" {
  description = "CIDR blocks for pod subnets (Phase 2)"
  type        = list(string)
  default     = []
}

variable "pod_subnet_cidrs_phase1" {
  description = "CIDR blocks for pod subnets (Phase 1) - tiny for exhaustion demo"
  type        = list(string)
  default     = []
}

# Availability Zones
variable "availability_zones" {
  description = "Availability zones to use"
  type        = list(string)
}

# AWS Region
variable "aws_region" {
  description = "AWS region"
  type        = string
}

# Phase Configuration
variable "phase" {
  description = "Deployment phase (1 or 2)"
  type        = number
}

# Cluster Name (for tagging)
variable "cluster_name" {
  description = "EKS cluster name for subnet tagging"
  type        = string
  default     = ""
}

# Tags
variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "large_node_subnet_cidrs" {
  description = "CIDR blocks for large node subnets (dedicated, for high pod density)"
  type        = list(string)
  default     = []
} 