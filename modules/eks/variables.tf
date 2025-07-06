# EKS Cluster Configuration
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "EKS cluster version"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

# Networking Configuration
variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs"
  type        = list(string)
}

variable "pod_subnet_ids" {
  description = "Pod subnet IDs (Phase 2)"
  type        = list(string)
  default     = []
}


# Phase Configuration
variable "phase" {
  description = "Deployment phase (1 or 2)"
  type        = number
}

# Tags
variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
} 