variable "aws_region" {
  description = "AWS region used by the project"
  type        = string
  default     = "il-central-1"
}

variable "project_name" {
  description = "Project name used for AWS resources"
  type        = string
  default     = "final-project"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "final-project"
}

variable "ecr_repository_name" {
  description = "ECR repository name"
  type        = string
  default     = "final-project"
}

variable "vpc_id" {
  description = "Existing VPC ID used by the EKS cluster"
  type        = string
}

variable "private_subnet_ids" {
  description = "Existing subnet IDs used by EKS"
  type        = list(string)
}

variable "node_instance_types" {
  description = "EC2 instance types for the EKS node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  type    = number
  default = 1
}

variable "node_min_size" {
  type    = number
  default = 1
}

variable "node_max_size" {
  type    = number
  default = 2
}