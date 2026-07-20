terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.33"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.16"
    }
  }

  # Shared Terraform state bucket bootstrapped by the EC2 DevOps agent.
  # Every environment/app of this repo reuses the bucket; only `key` changes.
  # use_lockfile enables native S3 state locking (Terraform >= 1.10) so no
  # DynamoDB lock table is required.
  backend "s3" {
    bucket       = "devops-ai-tfstate-478546323821"
    key          = "ai-demo/dev/ganna-ai/terraform.tfstate"
    region       = "us-west-2"
    use_lockfile = true
    encrypt      = true
  }
}
