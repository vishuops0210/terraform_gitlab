# Prod environment. Same module as lab, different inputs and separate state.
# This is the 3 plus 3 shape from your original diagram, with Multi-AZ RDS.
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
  environment = "prod"

  availability_zones = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]

  gitaly_count   = 3
  praefect_count = 3

  gitaly_instance_type   = "t3.xlarge"
  praefect_instance_type = "t3.large"

  gitaly_data_volume_size = 200

  rds_instance_class = "db.t3.small"
  rds_multi_az       = true

  # Never hardcode this. Set RDS_PASSWORD in your shell before apply.
  rds_password = get_env("RDS_PASSWORD", "")
}
