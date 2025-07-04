resource "helm_release" "ebs_csi_driver" {
  name             = "aws-ebs-csi-driver"
  repository       = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart            = "aws-ebs-csi-driver"
  namespace        = "kube-system"
  create_namespace = true

  set = [
    {
      name  = "controller.serviceAccount.create"
      value = "true"
    },
    {
      name  = "controller.serviceAccount.name"
      value = var.controller_sa_name
    },
    {
      name  = "controller.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = var.controller_sa_role_arn
    },
    {
      name  = "node.serviceAccount.create"
      value = "true"
    },
    {
      name  = "node.serviceAccount.name"
      value = var.node_sa_name
    },
    {
      name  = "storageClasses[0].name"
      value = "gp3"
    },
    {
      name  = "storageClasses[0].provisioner"
      value = "ebs.csi.aws.com"
    },
    {
      name  = "storageClasses[0].parameters.type"
      value = "gp3"
    },
    {
      name  = "storageClasses[0].parameters.fsType"
      value = "ext4"
    },
    {
      name  = "storageClasses[0].reclaimPolicy"
      value = "Delete"
    },
    {
      name  = "storageClasses[0].volumeBindingMode"
      value = "WaitForFirstConsumer"
    },
    {
      name  = "storageClasses[0].allowVolumeExpansion"
      value = "true"
    }
  ]

  depends_on = [var.kubeconfig_dependency]
}