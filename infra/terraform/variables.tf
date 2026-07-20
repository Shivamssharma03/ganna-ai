variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-west-2"
}

variable "vpc_cidr" {
  description = "CIDR block for the fresh VPC created for this app/env"
  type        = string
  default     = "10.60.0.0/16"
}

variable "node_instance_types" {
  description = "EC2 instance types for the EKS managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Desired managed node group size"
  type        = number
  default     = 4
}

variable "node_min_size" {
  description = "Minimum managed node group size"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum managed node group size"
  type        = number
  default     = 6
}

variable "github_actions_role_arn" {
  description = "OIDC role assumed by GitHub Actions; granted EKS cluster access"
  type        = string
  default     = "arn:aws:iam::478546323821:role/ai-demogaanaai-devops-dev-gha"
}

variable "datadog_api_key" {
  description = "Datadog API key, injected at apply time via TF_VAR_datadog_api_key from AWS Secrets Manager (/platform/dev/datadog, key api_key) - never set a real value here"
  type        = string
  sensitive   = true
  default     = ""
}
