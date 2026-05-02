variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (qa / staging / prod)"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "amiranet-cluster"
}

variable "cluster_version" {
  description = "Kubernetes version for EKS"
  type        = string
  default     = "1.34"
}

# ── Networking ───────────────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "AZs to use (leave empty to auto-pick the first 2 in the region)"
  type        = list(string)
  default     = []
}

# ── Node group ───────────────────────────────────────────────────────────────

variable "node_instance_types" {
  description = "EC2 instance types for the managed node group"
  type        = list(string)
  default     = ["t3a.medium"]
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 4
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_disk_size" {
  description = "Root EBS volume size in GB per node"
  type        = number
  default     = 20
}

# ── Sealed Secrets ────────────────────────────────────────────────────────────

variable "sealed_secrets_key" {
  description = "TLS private key exported from your local Sealed Secrets controller (PEM format)"
  type        = string
  sensitive   = true
}

variable "sealed_secrets_cert" {
  description = "TLS certificate exported from your local Sealed Secrets controller (PEM format)"
  type        = string
  sensitive   = true
}
