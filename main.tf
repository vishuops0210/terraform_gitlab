# GitLab hybrid, phase 1: VPC, subnets, Gitaly VMs, Praefect VMs, RDS, Route53.
# Phase 2 (EKS, Rails, Sidekiq, runners, ElastiCache, second RDS) is separate.
# This code provisions infra only. GitLab and Praefect software is installed
# by Ansible after apply, using the outputs in outputs.tf as inventory.
# No secrets are stored in this repo. RDS password comes from terraform.tfvars,
# which is gitignored, or from TF_VAR_rds_password.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Local state by default, for lab testing. For team use, uncomment the
  # S3 backend below, create that bucket first, and fill in the values.
  # backend "s3" {
  #   bucket         = "CHANGE-ME-terraform-state"
  #   key            = "gitlab-hybrid/phase1.tfstate"
  #   region         = "ap-south-1"
  #   dynamodb_table = "CHANGE-ME-terraform-lock"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

# Use the AZs given in variables, or the first two available AZs if none given.
locals {
  azs = length(var.availability_zones) > 0 ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, 2)
}
