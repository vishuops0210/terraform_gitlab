# Lab environment. This is your current 2 plus 2 setup.
# Usage, from this folder:
#   export RDS_PASSWORD="your-strong-password"
#   terragrunt init
#   terragrunt plan
#   terragrunt apply

include "root" {
  path = find_in_parent_folders("terragrunt.hcl")
}

terraform {
  source = "../.."
}

inputs = {
  aws_region  = "ap-south-1"
  project     = "gitlab-hybrid"
  environment = "lab"

  availability_zones = ["ap-south-1a", "ap-south-1b"]

  gitaly_count   = 2
  praefect_count = 2

  gitaly_instance_type   = "c7i-flex.large"
  praefect_instance_type = "c7i-flex.large"

  # Lab NAT: single NAT, for cost. Prod sets this to true for one NAT per AZ.
  nat_gateway_per_az = false

  gitaly_data_volume_size = 100

  # SSH with the existing default.pem key pair. This key pair must already
  # exist in AWS ap-south-1 with this exact name, otherwise apply will fail
  # and SSH with default.pem will not work. SSH is allowed only from inside
  # the VPC, so the in-VPC controller can SSH, not the internet.
  key_name          = "default"
  ssh_allowed_cidrs = ["10.10.0.0/16"]

  rds_instance_class = "db.t4g.micro"
  rds_multi_az       = false

  # Free Tier RDS: 20 GB is the module default, gp2 storage, no backups.
  rds_storage_type           = "gp2"
  rds_backup_retention_period = 0
  rds_allocated_storage      = 20

  # Never hardcode this. Set RDS_PASSWORD in your shell before apply.
  rds_password = get_env("RDS_PASSWORD", "")

  # EKS, Phase 2, lab: app 2 nodes, CI 1 node, both c7i-flex.large.
  eks_enabled            = true
  eks_version            = "1.32"
  eks_app_node_count     = 2
  eks_ci_node_count      = 1
  eks_app_instance_type  = "c7i-flex.large"
  eks_ci_instance_type   = "c7i-flex.large"

  # Rails RDS and Redis passwords, also from env, never in git.
  rails_db_password = get_env("RAILS_DB_PASSWORD", "")
  redis_auth_token  = get_env("REDIS_AUTH_TOKEN", "")
}
