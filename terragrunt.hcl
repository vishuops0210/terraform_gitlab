# Root Terragrunt config, shared by all environments.
# Do not put environment values here. Put them in live/lab/terragrunt.hcl
# and live/prod/terragrunt.hcl, as inputs.
# This file only sets remote state, so lab and prod get separate state files.
# State bucket: create it once first, or set TG_STATE_BUCKET, then change
# the default below to your real bucket name. Do not commit a password here.

remote_state {
  backend = "s3"

  config = {
    bucket         = get_env("TG_STATE_BUCKET", "CHANGE-ME-gitlab-hybrid-tfstate")
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = get_env("TG_LOCK_TABLE", "CHANGE-ME-gitlab-hybrid-tflock")
  }

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}
