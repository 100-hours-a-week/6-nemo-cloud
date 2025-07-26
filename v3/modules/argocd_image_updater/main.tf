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
  registries:
    - name: aws-ecr
      prefix: ${var.aws_account_id}.dkr.ecr.${var.region}.amazonaws.com
      api_url: https://${var.aws_account_id}.dkr.ecr.${var.region}.amazonaws.com
      ping: yes
      credentials: ext:/scripts/ecr-login.sh
      credsexpire: 10h

  git:
    branch: infra/applications
    email: onurivit01@gmail.com
    user: halfmoon01
    commitMessageTemplate: "🚀 Backend: update image to {{.NewTag}}"

authScripts:
  enabled: true
  scripts:
    ecr-login.sh: |
      #!/bin/sh
      # Read-only 파일시스템에서 AWS 설정을 임시 디렉토리로 변경
      export AWS_CONFIG_FILE=/tmp/aws-config
      export AWS_SHARED_CREDENTIALS_FILE=/tmp/aws-credentials
      
      # ECR 로그인 토큰 생성 및 반환
      echo "AWS:$(aws ecr get-login-password --region ${var.region})"

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

# Pod 설정에 임시 디렉토리 마운트 추가
podSpec:
  volumes:
    - name: tmp-dir
      emptyDir: {}
  containers:
    - name: argocd-image-updater
      volumeMounts:
        - name: tmp-dir
          mountPath: /tmp
      env:
        - name: AWS_CONFIG_FILE
          value: /tmp/aws-config
        - name: AWS_SHARED_CREDENTIALS_FILE
          value: /tmp/aws-credentials
        - name: AWS_REGION
          value: ${var.region}
        - name: AWS_ROLE_ARN
          value: ${aws_iam_role.argocd_image_updater_irsa.arn}
        - name: AWS_WEB_IDENTITY_TOKEN_FILE
          value: /var/run/secrets/eks.amazonaws.com/serviceaccount/token

# 로그 레벨을 debug로 설정하여 디버깅 용이하게 함
logLevel: debug
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