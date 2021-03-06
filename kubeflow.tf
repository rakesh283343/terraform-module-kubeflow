resource "kubernetes_namespace" "kubeflow" {
  depends_on = [module.istio.wait_for_crds, helm_release.cert_manager]
  metadata {
    name = "kubeflow"
    labels = {
      "control-plane"                    = "kubeflow"
      "katib-metricscollector-injection" = "enabled"
    }
  }
}

resource "k8s_manifest" "kubeflow_application_crd" {
  content = templatefile("${path.module}/manifests/kubeflow/application-crd.yaml", {}
  )
}

resource "k8s_manifest" "kubeflow_kfdef" {
  depends_on = [kubernetes_deployment.kubeflow_operator, k8s_manifest.kubeflow_application_crd]
  timeouts {
    delete = "5m"
  }
  content = templatefile("${path.module}/manifests/kubeflow/kfdef.yaml",
    { namespace = kubernetes_namespace.kubeflow.metadata.0.name }
  )
}

locals {
  kubeflow_ingress_vs_manifests = split("\n---\n", templatefile(
    "${path.module}/manifests/kubeflow/gateway-vs.yaml",
    {
      credential_name          = var.certificate_name,
      domain_name              = var.domain_name,
      istio_namespace          = var.istio_namespace
      ingress_gateway_selector = var.ingress_gateway_selector
      namespace                = kubernetes_namespace.kubeflow.metadata.0.name
      use_cert_manager         = var.use_cert_manager
    }
    )
  )
}

resource "k8s_manifest" "kubeflow_ingress_vs" {
  depends_on = [kubernetes_deployment.kubeflow_operator, module.istio.wait_for_crds, k8s_manifest.kubeflow_application_crd]
  count      = length(local.kubeflow_ingress_vs_manifests)
  content    = local.kubeflow_ingress_vs_manifests[count.index]
}


