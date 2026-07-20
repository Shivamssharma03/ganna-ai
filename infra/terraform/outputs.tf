output "vpc_id" {
  description = "ID of the ai-demo VPC."
  value       = module.vpc.vpc_id
}

output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for the EKS control plane."
  value       = module.eks.cluster_endpoint
}

output "ecr_repository_url" {
  description = "URL of the ai-demo-dev ECR repository."
  value       = aws_ecr_repository.ai_demo.repository_url
}
