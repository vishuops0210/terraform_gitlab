# ACM wildcard certificate for tyagi.fun, for ALB TLS on all future apps.
# One cert, reused by GitLab, ArgoCD, and any other app, via the cert ARN
# in their Ingress annotations. No new cert per app.
# Domain: *.tyagi.fun, plus bare tyagi.fun as a subject alternative name.
# Wildcard covers one level only: gitlab.tyagi.fun, argocd.tyagi.fun, etc.
# It does not cover dev.gitlab.tyagi.fun, and it does not cover internal
# services like praefect.internal, which do not need a public cert.
# Region: same as the ALB, ap-south-1, because an ALB can only use a cert
# from its own region. This is not a CloudFront cert, which would need
# us-east-1.
# Validation: DNS method, manual on purpose. This file does NOT hardcode
# a Route53 zone, because it was not confirmed that tyagi.fun is hosted
# in Route53 in this AWS account. After apply, terragrunt output shows
# the validation CNAME name and value for each domain. Add those CNAME
# records once at wherever tyagi.fun DNS is hosted, then ACM will issue
# the cert automatically, and will auto renew it as long as those records
# stay in place. If tyagi.fun later moves to Route53 in this account,
# validation records can be added here with aws_route53_record and
# aws_acm_certificate_validation, without changing the cert itself.
# Cost: ACM public certificates are free. Only the ALB and DNS cost.
# Gating: acm_enabled, lab true, prod false, so prod does not create a
# second duplicate cert for the same domain on a prod apply.

locals {
  acm_count = var.acm_enabled ? 1 : 0
}

resource "aws_acm_certificate" "tyagi" {
  count = local.acm_count

  domain_name       = var.acm_domain
  validation_method = "DNS"

  subject_alternative_names = var.acm_subject_alternative_names

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = var.acm_domain
  }
}
