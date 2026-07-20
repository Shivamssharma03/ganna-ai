variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-west-2"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster."
  type        = string
  default     = "1.35"
}

variable "vpc_cidr" {
  description = "CIDR block for the ai-demo VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones to spread public/private subnets across (one pair per AZ)."
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b", "us-west-2c"]
}

variable "node_instance_types" {
  description = "EC2 instance types for the EKS managed node group."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Desired number of nodes in the managed node group."
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of nodes in the managed node group."
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of nodes in the managed node group."
  type        = number
  default     = 4
}

variable "github_actions_role_arn" {
  description = "IAM role ARN assumed by the GitHub Actions OIDC workflow; granted EKS access via an access entry."
  type        = string
  default     = "arn:aws:iam::478546323821:role/ai-demo-dev-ganna-ai-gha"
}

variable "datadog_api_key" {
  description = "Datadog API key. Populated at pipeline runtime via TF_VAR_datadog_api_key, sourced from AWS Secrets Manager /platform/dev/datadog (json_key: api_key). Never set a literal value here."
  type        = string
  sensitive   = true
  default     = ""
}
