output "vpc_id" {
  description = "ID of the new VPC."
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs, one per AZ, where EC2 VMs live."
  value       = aws_subnet.private[*].id
}

output "data_subnet_ids" {
  description = "Data subnet IDs, one per AZ, where RDS lives."
  value       = aws_subnet.data[*].id
}

output "gitaly_private_ips" {
  description = "Private IPs of Gitaly VMs, in order gitaly-1, gitaly-2, and so on."
  value       = aws_instance.gitaly[*].private_ip
}

output "praefect_private_ips" {
  description = "Private IPs of Praefect VMs, in order praefect-1, praefect-2, and so on."
  value       = aws_instance.praefect[*].private_ip
}

output "gitaly_dns_names" {
  description = "Private DNS names for Gitaly VMs."
  value       = aws_route53_record.gitaly[*].fqdn
}

output "praefect_dns_names" {
  description = "Private DNS names for Praefect VMs."
  value       = aws_route53_record.praefect[*].fqdn
}

output "rds_endpoint" {
  description = "Endpoint of the Praefect RDS, host and port."
  value       = aws_db_instance.praefect.endpoint
}

output "rds_address" {
  description = "Address of the Praefect RDS, host only, for Praefect config."
  value       = aws_db_instance.praefect.address
}

output "route53_zone_id" {
  description = "ID of the private Route53 zone."
  value       = aws_route53_zone.internal.zone_id
}

output "praefect_nlb_dns_name" {
  description = "DNS name of the internal Praefect NLB."
  value       = aws_lb.praefect.dns_name
}

output "praefect_nlb_endpoint" {
  description = "Single Praefect endpoint for GitLab Rails, Shell, and EKS, host and port."
  value       = "praefect.${var.private_dns_zone}:2305"
}

output "praefect_nlb_arn" {
  description = "ARN of the internal Praefect NLB."
  value       = aws_lb.praefect.arn
}

output "eks_cluster_name" {
  description = "EKS cluster name, empty when EKS is disabled."
  value       = var.eks_enabled ? aws_eks_cluster.main[0].name : ""
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint, empty when EKS is disabled."
  value       = var.eks_enabled ? aws_eks_cluster.main[0].endpoint : ""
}

output "eks_oidc_issuer" {
  description = "EKS OIDC issuer, empty when EKS is disabled."
  value       = var.eks_enabled ? aws_eks_cluster.main[0].identity[0].oidc[0].issuer : ""
}

output "eks_lb_controller_role_arn" {
  description = "IRSA role ARN for AWS Load Balancer Controller, empty when EKS is disabled."
  value       = var.eks_enabled ? aws_iam_role.lb_controller[0].arn : ""
}

output "eks_gitlab_rails_role_arn" {
  description = "IRSA role ARN for GitLab Rails S3 access, empty when EKS is disabled."
  value       = var.eks_enabled ? aws_iam_role.gitlab_rails[0].arn : ""
}

output "eks_gitlab_toolbox_role_arn" {
  description = "IRSA role ARN for GitLab Toolbox S3 access, empty when EKS is disabled."
  value       = var.eks_enabled ? aws_iam_role.gitlab_toolbox[0].arn : ""
}

output "gitlab_s3_buckets" {
  description = "GitLab object storage bucket names, by type."
  value       = { for k, b in aws_s3_bucket.gitlab : k => b.bucket }
}

output "gitlab_bucket_prefix" {
  description = "Bucket prefix to use in values.yml REPLACE_BUCKET_PREFIX."
  value       = "${var.project}-${var.environment}"
}

output "rails_rds_endpoint" {
  description = "Rails RDS endpoint, for values.yml REPLACE_RAILS_RDS_ENDPOINT."
  value       = aws_db_instance.rails.endpoint
}

output "rails_rds_address" {
  description = "Rails RDS address, host only."
  value       = aws_db_instance.rails.address
}

output "redis_primary_endpoint" {
  description = "Redis primary endpoint, for values.yml REPLACE_REDIS_PRIMARY_ENDPOINT."
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "acm_certificate_arn" {
  description = "ACM wildcard certificate ARN, for ALB Ingress certificate-arn annotation, empty when ACM is disabled."
  value       = var.acm_enabled ? aws_acm_certificate.tyagi[0].arn : ""
}

output "acm_validation_options" {
  description = "ACM DNS validation CNAME records to add at the tyagi.fun DNS host, one per domain, empty when ACM is disabled."
  value       = var.acm_enabled ? aws_acm_certificate.tyagi[0].domain_validation_options : []
}
