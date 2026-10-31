# Secrets Manager secrets for GitLab, created by Terraform, for ESO.
# Copy this file to secrets.tf in the terraform_gitlab repo root.
# Do NOT put real passwords or tokens in this file or in git.
# Values come from env vars only, via variables.tf and live/lab/terragrunt.hcl.
# Names must start with gitlab-, to match the ESO IRSA policy:
# secretsmanager:GetSecretValue and DescribeSecret on secret:gitlab-*
# recovery_window_in_days = 0, so destroy and recreate with the same name works
# in lab. In prod, use 30 and do not set 0.
# WARNING: Terraform state will contain these secret values in plaintext,
# state bucket is encrypted at rest, but anyone with state read access can read
# them. That is the trade-off for creating secrets via Terraform. For prod,
# create secrets manually in Secrets Manager and do not store them in state.

data "http" "rds_ca" {
  url = "https://truststore.pki.rds.amazonaws.com/ap-south-1/ap-south-1-bundle.pem"
}

locals {
  gitlab_s3_connection = yamlencode({
    provider              = "AWS"
    region                = "ap-south-1"
    aws_access_key_id     = aws_iam_access_key.gitlab_s3.id
    aws_secret_access_key = aws_iam_access_key.gitlab_s3.secret
  })
}


resource "aws_secretsmanager_secret" "gitlab_db_password" {
  name                    = "gitlab-db-password"
  description             = "GitLab Rails RDS password, for ESO, namespace gitlab"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "gitlab_db_password" {
  secret_id     = aws_secretsmanager_secret.gitlab_db_password.id
  secret_string = var.rails_db_password
}

resource "aws_secretsmanager_secret" "gitlab_redis_password" {
  name                    = "gitlab-redis-password"
  description             = "GitLab Redis auth token, for ESO, namespace gitlab"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "gitlab_redis_password" {
  secret_id     = aws_secretsmanager_secret.gitlab_redis_password.id
  secret_string = var.redis_auth_token
}

resource "aws_secretsmanager_secret" "gitlab_praefect_token" {
  name                    = "gitlab-praefect-token"
  description             = "Praefect external token, must match Ansible vault token, for ESO"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "gitlab_praefect_token" {
  secret_id     = aws_secretsmanager_secret.gitlab_praefect_token.id
  secret_string = var.praefect_token
}

resource "aws_secretsmanager_secret" "gitlab_rails_storage" {
  name                    = "gitlab-rails-storage"
  description             = "GitLab S3 object storage connection, IRSA, for ESO"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "gitlab_rails_storage" {
  secret_id     = aws_secretsmanager_secret.gitlab_rails_storage.id
  secret_string = local.gitlab_s3_connection
}

resource "aws_secretsmanager_secret" "gitlab_rds_ca" {
  name                    = "gitlab-rds-ca"
  description             = "RDS CA bundle for ap-south-1, public CA, for ESO"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "gitlab_rds_ca" {
  secret_id     = aws_secretsmanager_secret.gitlab_rds_ca.id
  secret_string = data.http.rds_ca.response_body
}

resource "aws_secretsmanager_secret" "gitlab_smtp" {
  name                    = "gitlab-smtp"
  description             = "Brevo SMTP credentials, for ESO, namespace gitlab"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "gitlab_smtp" {
  secret_id     = aws_secretsmanager_secret.gitlab_smtp.id
  secret_string = jsonencode({
    username = var.smtp_username
    password = var.smtp_password
  })
}

