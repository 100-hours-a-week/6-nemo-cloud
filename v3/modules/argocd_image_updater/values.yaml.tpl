config:
  registriesConf:
    - name: aws
      prefix: ${aws_account_id}.dkr.ecr.${region}.amazonaws.com
      api_url: https://${aws_account_id}.dkr.ecr.${region}.amazonaws.com
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

webhook:
  enabled: true
  method: POST
  url: https://discord.com/api/webhooks/1392729701843341313/ppziPHdh0eWfrh29DhEX8f8iOFOKfMvzt9UFnERIYo-lCLeLiNyvg5-xONBZWifFZAaG
  headers:
    Content-Type: application/json
  payload: |
    {
      "content": "🚀 ArgoCD Image Updater\n✅ Application: `{{ .appName }}`\n📦 Image: `{{ .image }}`\n🆕 Tag: `{{ .newTag }}`"
    }

secret:
  create: true
  name: argocd-image-updater-secret
  data:
    github.token: ${github_pat}

serviceAccount:
  create: true
  name: argocd-image-updater
  annotations:
    eks.amazonaws.com/role-arn: ${role_arn}


extraArgs:
  - --registries-conf-path=/app/config/registries.conf.yaml

extraVolumes:
  - name: registry-config
    configMap:
      name: argocd-image-updater-registry

extraVolumeMounts:
  - name: registry-config
    mountPath: /app/config/registries.conf.yaml
    subPath: registries.conf.yaml