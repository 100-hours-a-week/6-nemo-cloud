
data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:argocd:argocd-image-updater"]
    }
  }
}

resource "aws_iam_role" "argocd_image_updater_irsa" {
  name               = "argocd-image-updater-irsa"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "attach_ecr_read" {
  role       = aws_iam_role.argocd_image_updater_irsa.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "helm_release" "argocd_image_updater" {
  name       = "argocd-image-updater"
  namespace  = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-image-updater"
  version    = "0.12.2"
  create_namespace = false

  values = [
    templatefile("${path.module}/values.yaml.tpl", {
      aws_account_id = var.aws_account_id,
      region         = var.region,
      github_pat     = var.github_pat,
      role_arn       = aws_iam_role.argocd_image_updater_irsa.arn
    })
  ]

  depends_on = [
    aws_iam_role_policy_attachment.attach_ecr_read,
    kubernetes_config_map.argocd_image_updater_registry]
}



terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0.0"
    }
  }
}

resource "kubernetes_config_map" "argocd_image_updater_registry" {
  metadata {
    name      = "argocd-image-updater-registry"
    namespace = "argocd"
  }

  data = {
    "registries.conf.yaml" = file("${path.module}/../../helm-charts/argocd-image-updater/registries.conf.yaml")
  }
}