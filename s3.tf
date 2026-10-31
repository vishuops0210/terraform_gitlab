# GitLab object storage buckets, plus runner cache bucket.
# One bucket per GitLab object type, matching values.yml.
# Registry bucket is NOT created here, registry is disabled in values.
# Bucket names use project and environment as prefix, so the values
# REPLACE_BUCKET_PREFIX becomes gitlab-hybrid-lab in lab.
# No public access, encryption on. Buckets are empty on creation,
# GitLab creates objects inside them after Helm install.

locals {
  gitlab_s3_buckets = {
    artifacts       = "artifacts"
    lfs             = "lfs"
    uploads         = "uploads"
    packages        = "packages"
    mr-diffs        = "mr-diffs"
    terraform-state = "terraform-state"
    ci-secure-files = "ci-secure-files"
    backups         = "backups"
    restore-tmp     = "restore-tmp"
    runner-cache    = "runner-cache"
  }
}

resource "aws_s3_bucket" "gitlab" {
  for_each = local.gitlab_s3_buckets

  bucket = "${var.project}-${var.environment}-${each.value}"

  tags = {
    Name = "${var.project}-${var.environment}-${each.value}"
    Role = "gitlab-object-storage"
  }
}

resource "aws_s3_bucket_public_access_block" "gitlab" {
  for_each = aws_s3_bucket.gitlab

  bucket = each.value.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "gitlab" {
  for_each = aws_s3_bucket.gitlab

  bucket = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# GitLab Rails and Toolbox S3 access, via IRSA. The service accounts
# gitlab-rails and gitlab-toolbox are created by kubectl or Helm after
# the cluster is up, with these role ARNs in their annotations.
# These roles are only created when EKS is enabled.
resource "aws_iam_policy" "gitlab_s3" {
  count = local.eks_count
  name  = "${local.eks_name}-gitlab-s3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ]
      Resource = concat(
        [for b in aws_s3_bucket.gitlab : b.arn],
        [for b in aws_s3_bucket.gitlab : "${b.arn}/*"]
      )
    }]
  })
}

resource "aws_iam_role" "gitlab_rails" {
  count = local.eks_count
  name  = "${local.eks_name}-gitlab-rails"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRoleWithWebIdentity"
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.eks[0].arn }
      Condition = {
        StringEquals = {
          "${replace(aws_iam_openid_connect_provider.eks[0].url, "https://", "")}:sub" = "system:serviceaccount:gitlab:gitlab-rails"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "gitlab_rails" {
  count      = local.eks_count
  role       = aws_iam_role.gitlab_rails[0].name
  policy_arn = aws_iam_policy.gitlab_s3[0].arn
}

resource "aws_iam_role" "gitlab_toolbox" {
  count = local.eks_count
  name  = "${local.eks_name}-gitlab-toolbox"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRoleWithWebIdentity"
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.eks[0].arn }
      Condition = {
        StringEquals = {
          "${replace(aws_iam_openid_connect_provider.eks[0].url, "https://", "")}:sub" = "system:serviceaccount:gitlab:gitlab-toolbox"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "gitlab_toolbox" {
  count      = local.eks_count
  role       = aws_iam_role.gitlab_toolbox[0].name
  policy_arn = aws_iam_policy.gitlab_s3[0].arn
}

# Runner manager S3 cache role: only the runner-cache bucket, not all
# GitLab buckets. Runner job pods use the manager role via IRSA.
resource "aws_iam_policy" "runner_cache" {
  count = local.eks_count
  name  = "${local.eks_name}-runner-cache"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ]
      Resource = [
        aws_s3_bucket.gitlab["runner-cache"].arn,
        "${aws_s3_bucket.gitlab["runner-cache"].arn}/*"
      ]
    }]
  })
}

resource "aws_iam_role" "runner_cache" {
  count = local.eks_count
  name  = "${local.eks_name}-runner-cache"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRoleWithWebIdentity"
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.eks[0].arn }
      Condition = {
        StringEquals = {
          "${replace(aws_iam_openid_connect_provider.eks[0].url, "https://", "")}:sub" = "system:serviceaccount:gitlab:gitlab-runner"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "runner_cache" {
  count      = local.eks_count
  role       = aws_iam_role.runner_cache[0].name
  policy_arn = aws_iam_policy.runner_cache[0].arn
}


resource "aws_iam_user" "gitlab_s3" {
  name = "${local.eks_name}-gitlab-s3"
}

resource "aws_iam_access_key" "gitlab_s3" {
  user = aws_iam_user.gitlab_s3.name
}

resource "aws_iam_user_policy_attachment" "gitlab_s3" {
  user       = aws_iam_user.gitlab_s3.name
  policy_arn = aws_iam_policy.gitlab_s3[0].arn
}
