# GitLab hybrid, Terraform phase 1

Provisions, in order: VPC, subnets, Gitaly VMs, Praefect VMs, RDS for Praefect, private Route53 zone, internal NLB for Praefect.

This is infra only. GitLab and Praefect software is installed by Ansible after apply, using the Terragrunt outputs as inventory.

This repo is Terragrunt only. Do not run Terraform directly from the repo root, and do not use a tfvars file. All values come from the environment folders below, and state is remote, managed by Terragrunt.

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

## Environments

- `terragrunt.hcl`: root config, only remote state. Lab state goes to `live/lab/terraform.tfstate`, prod state to `live/prod/terraform.tfstate`, in the same S3 bucket, so they never overwrite each other.
- `live/lab/terragrunt.hcl`: your current lab, 2 Gitaly plus 2 Praefect, single AZ RDS, `db.t3.micro`.
- `live/prod/terragrunt.hcl`: production shape, 3 Gitaly plus 3 Praefect, 3 AZs, Multi-AZ RDS, larger instances.

## Run it, on your machine with AWS credentials

Terragrunt and Terraform binaries are not installed on the assistant VM, so install both on your machine before running these commands.

First, create the state S3 bucket once, then set its name in the root `terragrunt.hcl` or via `TG_STATE_BUCKET`. No DynamoDB lock table is needed: locking uses native S3 locking, `use_lockfile = true`, which writes a `.tflock` file in the same bucket. This needs Terraform 1.11 or later, or OpenTofu 1.10 or later. Then, from one environment folder only:

```
cd live/lab
export RDS_PASSWORD="your-strong-password"
terragrunt init
terragrunt plan
terragrunt apply
terragrunt output
```

Check the plan carefully before apply: it should show 1 VPC, subnets, 2 Gitaly VMs plus 2 data volumes, 2 Praefect VMs, 1 RDS, 1 Route53 zone, 4 Route53 records for individual VMs plus 1 alias record for `praefect.internal`, and 1 internal NLB with its target group and listener.

To test prod later, just `cd ../prod` and run the same commands. No tfvars file to copy, no risk of applying lab values to prod, because the inputs live in that environment folder.

## Scale it

To change VM count, for example to 4 Gitaly and 3 Praefect, edit the inputs in `live/lab/terragrunt.hcl`:

```
gitaly_count   = 4
praefect_count = 3
```

Then, from `live/lab`, run `terragrunt apply`. New VMs are added at the end, and DNS records follow automatically.

To change VM size, change `gitaly_instance_type` or `praefect_instance_type` in the same file, then apply.

Warning on scaling down Gitaly: lowering `gitaly_count` destroys the highest numbered VMs and their data volumes. Check Praefect replication and that the remaining nodes have a full copy before scaling down.

## After apply, Ansible next steps

1. Use `terragrunt output` in the environment folder for private IPs and DNS names.
2. Point your Gitaly Ansible role at the Gitaly VMs, and your Praefect config at the Praefect VMs.
3. In Praefect config, use the RDS endpoint from `terragrunt output`, database `praefect_production`, and virtual storage nodes `gitaly-1.internal:8075`, `gitaly-2.internal:8075`, and so on.
4. On a Praefect VM, verify with sudo:
   `sudo gitlab-ctl praefect check`
   or the binary dial-nodes check against the Praefect config.

## Destroy, lab only

From `live/lab` only:

```
terragrunt destroy
```

This deletes the VMs, data volumes, RDS, and DNS records. Do not run this on a production setup without a backup.
