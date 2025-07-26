resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
     # ??? 이것도 서브넷은 배열로 받습니다. 
    subnet_ids = var.subnet_ids
  }
  depends_on = [aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy]
}

resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = var.node_group_name
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids
  
  scaling_config {
    desired_size = var.desired_capacity
    max_size     = var.max_capacity
    min_size     = var.min_capacity
  }
  # ??? instance_type 는 복수형 배열만 지원됩니다
  instance_types = var.instance_types

  # 보안 그룹 추가 (조건부로 SSH 키 설정)
  dynamic "remote_access" {
    for_each = var.key_pair_name != "" ? [1] : []
    content {
      ec2_ssh_key = var.key_pair_name
      source_security_group_ids = [aws_security_group.node_group.id]
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy
  ]
}

# EKS 노드 그룹용 보안 그룹
resource "aws_security_group" "node_group" {
  name        = "${var.cluster_name}-node-group-sg"
  description = "Security group for EKS node group"
  vpc_id      = var.vpc_id

  # Kafka NodePort 접근 허용 (AI 인스턴스에서)
  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "NodePort range for Kafka external access"
  }

  # Kafka external port 접근 허용
  ingress {
    from_port   = 9094
    to_port     = 9094
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Kafka external access port"
  }

  # 클러스터 내부 통신
  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    self      = true
    description = "All traffic from same security group"
  }

  # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS"
  }

  # SSH (옵션)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "SSH from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name = "${var.cluster_name}-node-group-sg"
  }
}

# 알려진 EKS remote access 보안 그룹에 직접 NodePort 규칙 추가
resource "aws_security_group_rule" "eks_remote_access_nodeport_direct" {
  type              = "ingress"
  from_port         = 30000
  to_port           = 32767
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  security_group_id = "sg-0fff56975bae37153"  # 확인된 EKS remote access 보안 그룹 ID
  description       = "NodePort range for Kafka external access"
}

# Kafka external port도 추가
resource "aws_security_group_rule" "eks_remote_access_kafka_external" {
  type              = "ingress"
  from_port         = 9094
  to_port           = 9094
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  security_group_id = "sg-0fff56975bae37153"
  description       = "Kafka external access port"
}

######################################
# IAM Roles (기존 클러스터/노드용)
######################################
resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# Node Group IAM Role
resource "aws_iam_role" "node" {
  name = "${var.cluster_name}-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver_managed_policy" {
  role       = aws_iam_role.ebs_csi_driver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}


######################################
# ✅ EBS CSI Driver용 IAM Role (IRSA)
######################################

resource "aws_iam_policy" "ebs_csi_driver" {
  name        = "AmazonEKS_EBS_CSI_Driver_Policy"
  description = "Policy for EBS CSI Driver"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "ec2:AttachVolume",
          "ec2:CreateSnapshot",
          "ec2:CreateTags",
          "ec2:CreateVolume",
          "ec2:DeleteSnapshot",
          "ec2:DeleteTags",
          "ec2:DeleteVolume",
          "ec2:DescribeInstances",
          "ec2:DescribeSnapshots",
          "ec2:DescribeTags",
          "ec2:DescribeVolumes",
          "ec2:DescribeAvailabilityZones",
          "ec2:DetachVolume"
        ],
        Resource = "*"
      }
    ]
  })
}


# OIDC Provider 생성 (EKS 클러스터에서 추출)
resource "aws_iam_openid_connect_provider" "this" {
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da0afd10df6"]
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

# IRSA용 IAM Role
resource "aws_iam_role" "ebs_csi_driver" {
  name = "${var.cluster_name}-ebs-csi-driver"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Federated = aws_iam_openid_connect_provider.this.arn
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
        }
      }
    }]
  })
}

# IAM 정책 연결 (EBS 볼륨 제어 권한)
resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  role       = aws_iam_role.ebs_csi_driver.name
  policy_arn = aws_iam_policy.ebs_csi_driver.arn
}


########## ECR ###########

########## ECR ###########

resource "aws_iam_role" "argocd_image_updater" {
  name = "${var.cluster_name}-argocd-image-updater"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = aws_iam_openid_connect_provider.this.arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:argocd:argocd-image-updater-sa"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "argocd_image_updater_ecr" {
  name        = "${var.cluster_name}-argocd-image-updater-ecr"
  description = "ECR access for ArgoCD Image Updater"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "argocd_image_updater_ecr" {
  role       = aws_iam_role.argocd_image_updater.name
  policy_arn = aws_iam_policy.argocd_image_updater_ecr.arn
}

resource "aws_iam_role_policy_attachment" "argocd_image_updater_ecr_readonly" {
  role       = aws_iam_role.argocd_image_updater.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}



#### KAFKA


resource "aws_iam_role" "kafka_irsa" {
  name = "${var.cluster_name}-kafka-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Federated = aws_iam_openid_connect_provider.this.arn
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kafka:kafka-sa"
        }
      }
    }]
  })
}


resource "aws_iam_role_policy" "kafka_irsa_policy" {
  name = "kafka-ecr-policy"
  role = aws_iam_role.kafka_irsa.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement: [
      {
        Effect: "Allow",
        Action: [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ],
        Resource: "*"
      }
    ]
  })
}

resource "aws_iam_policy" "kafka_s3_policy" {
  name = "${var.cluster_name}-kafka-s3-access"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket"
      ],
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "kafka_s3_attach" {
  role       = aws_iam_role.kafka_irsa.name
  policy_arn = aws_iam_policy.kafka_s3_policy.arn
}