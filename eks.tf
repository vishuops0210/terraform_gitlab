# EKS cluster, Phase 2. Infra only, no Helm releases here.
# Cluster and node groups are gated by var.eks_enabled, so prod does not
# get a cluster until its terragrunt.hcl sets eks_enabled = true.
# Lab: app node group 2 nodes, CI node group 1 node, both c7i-flex.large.
# Nodes live in the existing private subnets, no public IP, same VPC as
# Gitaly and Praefect. Control plane endpoint is public for demo kubectl
# access, private access is also on.
# Note on sizing: c7i-flex.large has 2 vCPU. A webservice pod asking for
# 4 CPU cannot schedule on a 2 vCPU node. For a cluster-only check this
# is fine. For GitLab pods to actually run, either lower webservice CPU
# request in values, or use larger app nodes later. This is recorded
# here so the lab check does not silently pass and then pods stay Pending.

locals {
  eks_count = var.eks_enabled ? 1 : 0
  eks_name  = "${var.project}-${var.environment}-eks"
}

resource "aws_iam_role" "eks_cluster" {
  count = local.eks_count
  name  = "${local.eks_name}-cluster"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster" {
  count      = local.eks_count
  role       = aws_iam_role.eks_cluster[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "eks_node" {
  count = local.eks_count
  name  = "${local.eks_name}-node"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_node_worker" {
  count      = local.eks_count
  role       = aws_iam_role.eks_node[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_node_cni" {
  count      = local.eks_count
  role       = aws_iam_role.eks_node[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_node_ecr" {
  count      = local.eks_count
  role       = aws_iam_role.eks_node[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "eks_node_ssm" {
  count      = local.eks_count
  role       = aws_iam_role.eks_node[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_eks_cluster" "main" {
  count    = local.eks_count
  name     = local.eks_name
  role_arn = aws_iam_role.eks_cluster[0].arn
  version  = var.eks_version

  vpc_config {
    subnet_ids              = aws_subnet.private[*].id
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster]
}

resource "aws_eks_node_group" "app" {
  count           = local.eks_count
  cluster_name    = aws_eks_cluster.main[0].name
  node_group_name = "${local.eks_name}-app"
  node_role_arn   = aws_iam_role.eks_node[0].arn
  subnet_ids      = aws_subnet.private[*].id
  instance_types  = [var.eks_app_instance_type]
  capacity_type   = "ON_DEMAND"

  scaling_config {
    desired_size = var.eks_app_node_count
    min_size     = var.eks_app_node_count
    max_size     = var.eks_app_node_count
  }

  labels = {
    workload = "gitlab-app"
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_worker,
    aws_iam_role_policy_attachment.eks_node_cni,
    aws_iam_role_policy_attachment.eks_node_ecr,
  ]
}

resource "aws_eks_node_group" "ci" {
  count           = local.eks_count
  cluster_name    = aws_eks_cluster.main[0].name
  node_group_name = "${local.eks_name}-ci"
  node_role_arn   = aws_iam_role.eks_node[0].arn
  subnet_ids      = aws_subnet.private[*].id
  instance_types  = [var.eks_ci_instance_type]
  capacity_type   = "ON_DEMAND"

  scaling_config {
    desired_size = var.eks_ci_node_count
    min_size     = var.eks_ci_node_count
    max_size     = var.eks_ci_node_count
  }

  labels = {
    workload = "gitlab-ci"
  }

  taint {
    key    = "gitlab-ci"
    value  = "true"
    effect = "NO_SCHEDULE"
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_worker,
    aws_iam_role_policy_attachment.eks_node_cni,
    aws_iam_role_policy_attachment.eks_node_ecr,
  ]
}

resource "aws_eks_addon" "vpc_cni" {
  count        = local.eks_count
  cluster_name = aws_eks_cluster.main[0].name
  addon_name   = "vpc-cni"
}

resource "aws_eks_addon" "coredns" {
  count        = local.eks_count
  cluster_name = aws_eks_cluster.main[0].name
  addon_name   = "coredns"
}

resource "aws_eks_addon" "kube_proxy" {
  count        = local.eks_count
  cluster_name = aws_eks_cluster.main[0].name
  addon_name   = "kube-proxy"
}

# OIDC provider for IRSA. Thumbprint below is the standard EKS OIDC
# thumbprint used in AWS examples for this provider.
resource "aws_iam_openid_connect_provider" "eks" {
  count = local.eks_count
  url   = aws_eks_cluster.main[0].identity[0].oidc[0].issuer

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]
}

# IRSA role helper pattern: each role trusts the OIDC provider for one
# Kubernetes service account. The service accounts themselves are created
# by Helm or kubectl after the cluster is up, with the matching annotation.
resource "aws_iam_role" "ebs_csi" {
  count = local.eks_count
  name  = "${local.eks_name}-ebs-csi"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRoleWithWebIdentity"
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.eks[0].arn }
      Condition = {
        StringEquals = {
          "${replace(aws_iam_openid_connect_provider.eks[0].url, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  count      = local.eks_count
  role       = aws_iam_role.ebs_csi[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_eks_addon" "ebs_csi" {
  count                    = local.eks_count
  cluster_name             = aws_eks_cluster.main[0].name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.ebs_csi[0].arn
}

# ALB controller IRSA role. Terragrunt creates this role only.
# The controller pod itself is installed by Helm after the cluster is up,
# see README for the helm command. That is the same infra-only rule as
# Phase 1: Terraform creates IAM and infra, Helm creates software.
resource "aws_iam_policy" "lb_controller" {
  count       = local.eks_count
  name        = "${local.eks_name}-lb-controller"
  description = "Permissions for AWS Load Balancer Controller."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeAddresses",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeVpcs",
          "ec2:DescribeVpcClassicLink",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeTags",
          "ec2:GetCoipPoolUsage",
          "ec2:DescribeCoipPools",
          "ec2:GetSecurityGroupsForVpc",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeListenerCertificates",
          "elasticloadbalancing:DescribeSSLPolicies",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetGroupAttributes",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:DescribeTags",
          "elasticloadbalancing:DescribeTrustStores"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:DescribeUserPoolClient",
          "acm:ListCertificates",
          "acm:DescribeCertificate",
          "iam:ListServerCertificates",
          "iam:GetServerCertificate",
          "waf-regional:GetWebACL",
          "waf-regional:GetWebACLForResource",
          "waf-regional:AssociateWebACL",
          "waf-regional:DisassociateWebACL",
          "wafv2:GetWebACL",
          "wafv2:GetWebACLForResource",
          "wafv2:AssociateWebACL",
          "wafv2:DisassociateWebACL",
          "shield:GetSubscriptionState",
          "shield:DescribeProtection",
          "shield:CreateProtection",
          "shield:DeleteProtection"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:CreateSecurityGroup",
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "ec2:DeleteSecurityGroup"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:CreateTargetGroup",
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:CreateRule",
          "elasticloadbalancing:DeleteRule",
          "elasticloadbalancing:DeleteTargetGroup",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:SetIpAddressType",
          "elasticloadbalancing:SetSecurityGroups",
          "elasticloadbalancing:SetSubnets",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:AddListenerCertificates",
          "elasticloadbalancing:RemoveListenerCertificates",
          "elasticloadbalancing:ModifyRule",
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:DeregisterTargets",
          "elasticloadbalancing:SetWebAcl",
          "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:ModifyTargetGroupAttributes",
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags",
          "elasticloadbalancing:ModifyListenerAttributes"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["iam:CreateServiceLinkedRole"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "iam:AWSServiceName" = "elasticloadbalancing.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role" "lb_controller" {
  count = local.eks_count
  name  = "${local.eks_name}-lb-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRoleWithWebIdentity"
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.eks[0].arn }
      Condition = {
        StringEquals = {
          "${replace(aws_iam_openid_connect_provider.eks[0].url, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lb_controller" {
  count      = local.eks_count
  role       = aws_iam_role.lb_controller[0].name
  policy_arn = aws_iam_policy.lb_controller[0].arn
}

# External Secrets IRSA role: read GitLab secrets from Secrets Manager.
resource "aws_iam_policy" "external_secrets" {
  count = local.eks_count
  name  = "${local.eks_name}-external-secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
      Resource = "arn:aws:secretsmanager:${var.aws_region}:*:secret:gitlab-*"
    }]
  })
}

resource "aws_iam_role" "external_secrets" {
  count = local.eks_count
  name  = "${local.eks_name}-external-secrets"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRoleWithWebIdentity"
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.eks[0].arn }
      Condition = {
        StringEquals = {
          "${replace(aws_iam_openid_connect_provider.eks[0].url, "https://", "")}:sub" = "system:serviceaccount:external-secrets:external-secrets"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "external_secrets" {
  count      = local.eks_count
  role       = aws_iam_role.external_secrets[0].name
  policy_arn = aws_iam_policy.external_secrets[0].arn
}
