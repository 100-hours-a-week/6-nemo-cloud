
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
  version    = "0.9.2"
  create_namespace = false

  values = [<<EOF
config:
  registriesConf: |
    - name: aws
      prefix: ${var.aws_account_id}.dkr.ecr.${var.region}.amazonaws.com
      api_url: https://${var.aws_account_id}.dkr.ecr.${var.region}.amazonaws.com
      ping: true
      credentials:
        use_aws_sdk: true

  git:
    writeBranch: infra/application
    user:
      name: halfmoon01
      email: onurivit01@gmail.com
    commitMessageTemplate: "Chore: update image to {{ .NewImage }}"
    pgpSign: false
    
secret:
  create: true
  name: argocd-image-updater-secret
  data:
    github.token: ${var.github_pat}

serviceAccount:
  create: true
  name: argocd-image-updater
  annotations:
    eks.amazonaws.com/role-arn: ${aws_iam_role.argocd_image_updater_irsa.arn}
EOF
  ]

  depends_on = [aws_iam_role_policy_attachment.attach_ecr_read]
}



terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0.0"
    }
  }
}