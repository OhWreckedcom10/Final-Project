output "cluster_name" {
  value = data.aws_eks_cluster.existing.name
}

output "cluster_endpoint" {
  value     = data.aws_eks_cluster.existing.endpoint
  sensitive = true
}

output "ecr_repository_url" {
  value = aws_ecr_repository.application.repository_url
}

output "aws_region" {
  value = var.aws_region
}