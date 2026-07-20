# Datadog is a default EKS add-on, always installed alongside the cluster.
# The API key value never lives in Terraform code - it arrives at apply time
# via TF_VAR_datadog_api_key, exported by the pipeline from AWS Secrets
# Manager (/platform/dev/datadog, json_key: api_key). See
# deploy/secret-vars.dev.yaml for the source mapping.
resource "kubernetes_namespace" "datadog" {
  metadata {
    name = "datadog"
  }

  depends_on = [module.eks]
}

resource "kubernetes_secret" "datadog" {
  metadata {
    name      = "datadog-secret"
    namespace = kubernetes_namespace.datadog.metadata[0].name
  }

  data = {
    api-key = var.datadog_api_key
  }

  type = "Opaque"
}

resource "helm_release" "datadog" {
  name       = "datadog-agent"
  repository = "https://helm.datadoghq.com"
  chart      = "datadog"
  # Operator-reviewed chart version - bump deliberately, never track "latest".
  version           = "3.86.0"
  namespace         = kubernetes_namespace.datadog.metadata[0].name
  create_namespace  = false
  dependency_update = true

  set {
    name  = "datadog.apiKeyExistingSecret"
    value = kubernetes_secret.datadog.metadata[0].name
  }

  set {
    name  = "datadog.site"
    value = "datadoghq.com"
  }

  set {
    name  = "clusterName"
    value = local.cluster_name
  }

  set {
    name  = "datadog.kubelet.tlsVerify"
    value = "false"
  }

  depends_on = [kubernetes_secret.datadog, module.eks]
}
