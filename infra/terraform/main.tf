data "aws_availability_zones" "available" {
  state = "available"
}

# ---------------------------------------------------------------------------
# VPC - fresh network for this app/env (3 public + 3 private subnets, one
# cost-saving NAT gateway). Not a data-source lookup: this is a first-time
# deployment for this app/env.
# ---------------------------------------------------------------------------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = "ai-demogaanaai-devops"
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  public_subnets  = [for i in range(3) : cidrsubnet(var.vpc_cidr, 4, i)]
  private_subnets = [for i in range(3) : cidrsubnet(var.vpc_cidr, 4, i + 3)]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = {
    Application = "ai-demogaanaai-devops"
    Environment = "dev"
  }
}

# ---------------------------------------------------------------------------
# EKS cluster + managed node group.
# Deliberately no module-level depends_on on module.vpc: referencing
# module.vpc outputs directly gives Terraform the resource-level edges it
# needs, without deferring aws_partition/aws_caller_identity data (which
# would make the node group's `count` unknown at plan time).
# ---------------------------------------------------------------------------
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = "ai-demogaanaai-devops-dev"
  kubernetes_version = "1.35"

  # Private endpoint for in-VPC access; public endpoint stays enabled so
  # GitHub-hosted runners can reach the API. Worker-node ingress is scoped by
  # the module's own cluster/node security groups, never opened to 0.0.0.0/0.
  endpoint_private_access = true
  endpoint_public_access  = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  enable_cluster_creator_admin_permissions = true
  authentication_mode                      = "API_AND_CONFIG_MAP"

  iam_role_name            = "ai-demogaanaai-devops-dev-cluster"
  iam_role_use_name_prefix = false

  addons = {
    # before_compute = true avoids the node-readiness deadlock where nodes
    # register but stay NotReady waiting on the CNI DaemonSet.
    vpc-cni = {
      before_compute           = true
      service_account_role_arn = module.vpc_cni_irsa.arn
    }
    coredns    = {}
    kube-proxy = {}
    aws-ebs-csi-driver = {
      service_account_role_arn = module.ebs_csi_irsa.arn
    }
  }

  eks_managed_node_groups = {
    default = {
      name                     = "ai-demogaanaai-devops-dev-default"
      iam_role_name            = "ai-demogaanaai-devops-dev-node"
      iam_role_use_name_prefix = false
      instance_types           = var.node_instance_types

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      subnet_ids = module.vpc.private_subnets

      # Client-side timeouts only - these do not override AWS's own node
      # health deadline, they just stop Terraform giving up on a slow but
      # healthy operation.
      timeouts = {
        create = "60m"
        update = "60m"
        delete = "30m"
      }
    }
  }

  tags = {
    Application = "ai-demogaanaai-devops"
    Environment = "dev"
  }
}

# ---------------------------------------------------------------------------
# IRSA roles for the EBS CSI driver and VPC CNI add-ons. Names are explicit
# (never module defaults) because IAM role/policy names are unique
# account-wide.
# ---------------------------------------------------------------------------
module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.0"

  name                  = "ai-demogaanaai-devops-dev-ebs-csi"
  policy_name           = "ai-demogaanaai-devops-dev-ebs-csi"
  use_name_prefix       = false
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = {
    Application = "ai-demogaanaai-devops"
    Environment = "dev"
  }
}

module "vpc_cni_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.0"

  name            = "ai-demogaanaai-devops-dev-vpc-cni"
  policy_name     = "ai-demogaanaai-devops-dev-vpc-cni"
  use_name_prefix = false

  # IPv4 cluster: without this the generated policy only contains
  # ec2:CreateTags, missing the ENI/private-IP actions aws-node needs.
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }

  tags = {
    Application = "ai-demogaanaai-devops"
    Environment = "dev"
  }
}

# ---------------------------------------------------------------------------
# EKS access for the GitHub Actions OIDC role, so the deploy workflow can
# apply manifests/roll out deployments.
# ---------------------------------------------------------------------------
resource "aws_eks_access_entry" "github_actions" {
  cluster_name  = module.eks.cluster_name
  principal_arn = var.github_actions_role_arn
  type          = "STANDARD"

  tags = {
    Application = "ai-demogaanaai-devops"
    Environment = "dev"
  }
}

# NOTE: cluster-admin is broad. Tighten this to a namespace/app-scoped access
# policy before this environment is treated as production-like.
resource "aws_eks_access_policy_association" "github_actions_admin" {
  cluster_name  = module.eks.cluster_name
  principal_arn = var.github_actions_role_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

# ---------------------------------------------------------------------------
# ECR repository - one per environment of this app.
# ---------------------------------------------------------------------------
resource "aws_ecr_repository" "app" {
  name                 = "ai-demogaanaai-devops-dev"
  image_tag_mutability = "IMMUTABLE"

  encryption_configuration {
    encryption_type = "AES256"
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Application = "ai-demogaanaai-devops"
    Environment = "dev"
  }
}

# ---------------------------------------------------------------------------
# Datadog - default EKS add-on. API key comes in via TF_VAR_datadog_api_key,
# exported by infra-apply.yml from Secrets Manager (/platform/dev/datadog).
# ---------------------------------------------------------------------------
resource "kubernetes_namespace" "datadog" {
  metadata {
    name = "datadog"
  }

  depends_on = [module.eks]
}

resource "helm_release" "datadog" {
  name       = "datadog"
  repository = "https://helm.datadoghq.com"
  chart      = "datadog"
  version    = ">= 3.60.0"
  namespace  = kubernetes_namespace.datadog.metadata[0].name

  set_sensitive {
    name  = "datadog.apiKey"
    value = var.datadog_api_key
  }

  set {
    name  = "datadog.clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "datadog.kubelet.tlsVerify"
    value = "false"
  }

  depends_on = [module.eks]
}
