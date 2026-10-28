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

  gitaly_instance_type   = "t3.large"
  praefect_instance_type = "t3.large"

  gitaly_data_volume_size = 100

  rds_instance_class = "db.t4g.micro"
  rds_multi_az       = false

  # Free Tier RDS: 20 GB is the module default, gp2 storage, no backups.
  rds_storage_type           = "gp2"
  rds_backup_retention_period = 0
  rds_allocated_storage      = 20

  # Never hardcode this. Set RDS_PASSWORD in your shell before apply.
  rds_password = get_env("RDS_PASSWORD", "")
}
