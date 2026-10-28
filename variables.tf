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
  description = "Optional EC2 key pair name for SSH. Leave null for SSM Session Manager only, which is the recommended path."
  type        = string
  default     = null
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
  description = "PostgreSQL engine version for the Praefect database."
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
  description = "Master username for the Praefect RDS."
  type        = string
  default     = "praefect"
}

variable "rds_password" {
  description = "Master password for the Praefect RDS. Set from Terragrunt inputs via the RDS_PASSWORD environment variable, never in git."
  type        = string
  sensitive   = true
}
