# GitLab hybrid, Terraform phase 1

Provisions, in order: VPC, subnets, Gitaly VMs, Praefect VMs, RDS for Praefect, private Route53 zone.

This is infra only. GitLab and Praefect software is installed by Ansible after apply, using the Terraform outputs as inventory.

## What it creates

- VPC 10.10.0.0/16, ap-south-1, with public, private, and data subnets per AZ
- 1 NAT gateway in the first AZ, for lab cost. Production should use one per AZ.
- Gitaly VMs: count from `gitaly_count`, default 2, each with a separate encrypted EBS data volume on /dev/sdf
- Praefect VMs: count from `praefect_count`, default 2
- RDS PostgreSQL, database `praefect_production`, private only, Praefect security group only
- Private Route53 zone `internal`, with `gitaly-1.internal`, `gitaly-2.internal`, `praefect-1.internal`, and so on, generated from the VMs
- Internal Network Load Balancer in front of Praefect, TCP 2305, with cross-zone load balancing. Single endpoint: `praefect.internal:2305`. Target group attachments follow `praefect_count` automatically.
- IAM role for SSM Session Manager on all VMs. No SSH ingress by default.

This RDS is for Praefect only. The main GitLab Rails RDS is phase 2 and is not in this code.

## Test it, on your machine with AWS credentials

Terraform and AWS CLI are not available on the assistant VM, so this code has not been applied yet. Test it from your machine, where you already have AWS access:

```
cd gitlab-hybrid-terraform
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars, set rds_password only
terraform init
terraform fmt -check
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
terraform output
```

Check the plan carefully before apply: it should show 1 VPC, subnets, 2 Gitaly VMs plus 2 data volumes, 2 Praefect VMs, 1 RDS, 1 Route53 zone, 4 Route53 records for individual VMs plus 1 alias record for `praefect.internal`, and 1 internal NLB with its target group and listener.

## Terragrunt, for environment management

Yes, use Terragrunt for this. It does not replace Terraform, it wraps it: same module, different inputs per environment, and separate state per environment.

Structure:

- `terragrunt.hcl`: root config, only remote state. Lab state goes to `live/lab/terraform.tfstate`, prod state to `live/prod/terraform.tfstate`, in the same S3 bucket, so they never overwrite each other.
- `live/lab/terragrunt.hcl`: your current lab, 2 Gitaly plus 2 Praefect, single AZ RDS, `db.t3.micro`.
- `live/prod/terragrunt.hcl`: production shape, 3 Gitaly plus 3 Praefect, 3 AZs, Multi-AZ RDS, larger instances.

To use it, first create the state S3 bucket and DynamoDB lock table once, then set their names in the root `terragrunt.hcl` or via `TG_STATE_BUCKET` and `TG_LOCK_TABLE`. Then, from one environment folder only:

```
cd live/lab
export RDS_PASSWORD="your-strong-password"
terragrunt init
terragrunt plan
terragrunt apply
terragrunt output
```

To test prod later, just `cd ../prod` and run the same commands. No tfvars file to copy, no risk of applying lab values to prod, because the inputs live in that environment folder.

Plain Terraform still works as above, without Terragrunt. Terragrunt is the recommended path once you have more than one environment, because it keeps state and inputs separate by design.

Note: Terragrunt and Terraform binaries are not installed on the assistant VM, so install both on your machine before running these commands.

## Scale it

To change VM count, for example to 4 Gitaly and 3 Praefect:

```
# in terraform.tfvars
gitaly_count = 4
praefect_count = 3
```

Then `terraform apply`. New VMs are added at the end, and DNS records follow automatically.

To change VM size, change `gitaly_instance_type` or `praefect_instance_type`, then apply.

Warning on scaling down Gitaly: lowering `gitaly_count` destroys the highest numbered VMs and their data volumes. Check Praefect replication and that the remaining nodes have a full copy before scaling down.

## After apply, Ansible next steps

1. Use `terraform output` for private IPs and DNS names.
2. Point your Gitaly Ansible role at the Gitaly VMs, and your Praefect config at the Praefect VMs.
3. In Praefect config, use the RDS endpoint from `terraform output`, database `praefect_production`, and virtual storage nodes `gitaly-1.internal:8075`, `gitaly-2.internal:8075`, and so on.
4. On a Praefect VM, verify with sudo:
   `sudo gitlab-ctl praefect check`
   or the binary dial-nodes check against the Praefect config.

## Destroy, lab only

```
terraform destroy
```

This deletes the VMs, data volumes, RDS, and DNS records. Do not run this on a production setup without a backup.
