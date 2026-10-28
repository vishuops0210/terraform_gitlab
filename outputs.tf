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
