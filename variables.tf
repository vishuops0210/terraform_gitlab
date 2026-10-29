variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "ap-south-1"
}

variable "project" {
  description = "Name prefix for tags and resource names."
  type        = string
  default     = "gitlab-hybrid"
}

variable "environment" {
  description = "Environment tag, for example lab, staging, prod."
  type        = string
  default     = "lab"
}

variable "vpc_cidr" {
  description = "CIDR for the new VPC. Subnets are derived from this automatically."
  type        = string
  default     = "10.10.0.0/16"
}

variable "availability_zones" {
  description = "AZs to use. Leave empty to use the first two available AZs."
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
}

variable "nat_gateway_per_az" {
  description = "NAT gateway mode. False means one NAT gateway in the first AZ, for lab cost. True means one NAT gateway, one EIP, and one private route table per AZ, for production HA. Prod with 3 AZs creates 3 NAT gateways."
  type        = bool
  default     = false
}

variable "private_dns_zone" {
  description = "Private Route53 zone name for internal hostnames."
  type        = string
  default     = "internal"
}

# Scaling: change these numbers in the environment terragrunt.hcl, then run terragrunt apply from that environment folder.
# Raising a count adds new VMs at the end. Lowering a count destroys
# the highest numbered VMs first. Check Praefect replication before
# scaling Gitaly down, because that node's data volume is also deleted.
variable "gitaly_count" {
  description = "Number of Gitaly VMs. Start with 2 for this lab, use 3 for production."
  type        = number
  default     = 2

  validation {
    condition     = var.gitaly_count >= 1
    error_message = "gitaly_count must be at least 1."
  }
}

variable "praefect_count" {
  description = "Number of Praefect VMs. Start with 2 for this lab, use 3 for production."
  type        = number
  default     = 2

  validation {
    condition     = var.praefect_count >= 1
    error_message = "praefect_count must be at least 1."
  }
}

variable "gitaly_instance_type" {
  description = "EC2 instance type for Gitaly VMs. Change this to scale VM size up or down."
  type        = string
  default     = "t3.large"
}

variable "praefect_instance_type" {
  description = "EC2 instance type for Praefect VMs. Change this to scale VM size up or down."
  type        = string
  default     = "t3.large"
}

variable "gitaly_root_volume_size" {
  description = "Root volume size in GB for Gitaly VMs."
  type        = number
  default     = 30
}

variable "praefect_root_volume_size" {
  description = "Root volume size in GB for Praefect VMs."
  type        = number
  default     = 30
}

variable "gitaly_data_volume_size" {
  description = "Separate encrypted data volume size in GB for each Gitaly VM, attached as /dev/sdf."
  type        = number
  default     = 100
}

variable "key_name" {
  description = "EC2 key pair name for SSH, already existing in AWS. Set to default to use the existing default.pem key pair. Leave null for SSM Session Manager only."
  type        = string
  default     = null
}

variable "ssh_allowed_cidrs" {
  description = "CIDR blocks allowed to SSH to Gitaly and Praefect on port 22. Leave empty for no SSH ingress. For lab, use the VPC CIDR so only the in-VPC controller can SSH, never 0.0.0.0/0."
  type        = list(string)
  default     = []
}

# RDS, Praefect database only. This is NOT the main GitLab Rails database.
# That second RDS comes in phase 2.
variable "rds_instance_class" {
  description = "RDS instance class for the Praefect database. db.t4g.micro is the Free Tier Graviton class for lab."
  type        = string
  default     = "db.t4g.micro"
}

variable "rds_allocated_storage" {
  description = "RDS storage in GB for the Praefect database."
  type        = number
  default     = 20
}

variable "rds_engine_version" {
  description = "PostgreSQL engine version for the Praefect database. GitLab 19 requires PostgreSQL 17, minimum and maximum 17.x, so use major version 17 only and let AWS pick the latest minor available in ap-south-1. Do not use 16 with GitLab 19, and do not use 18 as the supported range for GitLab 19."
  type        = string
  default     = "17"
}

variable "rds_multi_az" {
  description = "Enable Multi-AZ for the Praefect RDS. Keep false for lab cost, set true for production."
  type        = bool
  default     = false
}

variable "rds_storage_type" {
  description = "RDS storage type. Use gp2 for AWS Free Tier, gp3 for production performance."
  type        = string
  default     = "gp2"
}

variable "rds_backup_retention_period" {
  description = "RDS automated backup retention in days. Use 0 for AWS Free Tier, free tier restricts backup retention to 0. Use 7 for production."
  type        = number
  default     = 0
}

variable "rds_username" {
  description = "Master username for the Praefect RDS. Use postgres, the PostgreSQL default, so it does not conflict with the Ansible Praefect service user praefect. Master postgres creates service praefect, membership grant and revoke then work as in the manual lab."
  type        = string
  default     = "postgres"
}

variable "rds_password" {
  description = "Master password for the Praefect RDS. Set from Terragrunt inputs via the RDS_PASSWORD environment variable, never in git."
  type        = string
  sensitive   = true
}
