# Fresh-deploy EKS cluster + managed node group + new IAM roles.
# IAM role/policy names below are explicitly set to the ai-demo-dev- prefix -
# never left to the module's own defaults - per the naming/permissions
# boundary requirement.
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access = true

  # EKS access entries (API), not the legacy aws-auth ConfigMap.
  authentication_mode                      = "API_AND_CONFIG_MAP"
  enable_cluster_creator_admin_permissions = true

  iam_role_name            = "ai-demo-dev-cluster-role"
  iam_role_use_name_prefix = false

  eks_managed_node_group_defaults = {
    iam_role_use_name_prefix = false
  }

  eks_managed_node_groups = {
    default = {
      name           = "ai-demo-dev-ng"
      instance_types = var.node_instance_types

      desired_size = var.node_desired_size
      min_size     = var.node_min_size
      max_size     = var.node_max_size

      iam_role_name = "ai-demo-dev-node-role"
    }
  }

  cluster_addons = {
    vpc-cni = {
      most_recent = true
    }
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_irsa.iam_role_arn
    }
  }

  # Grant the GitHub Actions OIDC workflow role access to the cluster so it
  # can deploy the application. Cluster-admin is used for simplicity here -
  # tighten to an app/namespace-scoped policy before production use.
  access_entries = {
    github_actions = {
      principal_arn = var.github_actions_role_arn

      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  tags = local.tags
}

# IRSA role for the aws-ebs-csi-driver add-on, named per the ai-demo-dev-
# permissions-boundary prefix rather than the module's default naming.
module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.44"

  role_name             = "ai-demo-dev-ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = local.tags
}
