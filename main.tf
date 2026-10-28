# GitLab hybrid, phase 1: VPC, subnets, Gitaly VMs, Praefect VMs, RDS, Route53.
# Phase 2 (EKS, Rails, Sidekiq, runners, ElastiCache, second RDS) is separate.
# This code provisions infra only. GitLab and Praefect software is installed
# by Ansible after apply, using the outputs in outputs.tf as inventory.
# No secrets are stored in this repo. RDS password comes from Terragrunt
# inputs, via the RDS_PASSWORD environment variable in each environment folder.
# Backend state is managed by Terragrunt, in the root terragrunt.hcl.
# Do not run this module directly, and do not add a local backend here.

terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
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
