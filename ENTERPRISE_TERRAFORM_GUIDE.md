# OpenHelp Enterprise Terraform Guide

## 1. Architecture objective

The repository follows a strict layered design:

`bootstrap -> network -> compute -> platform`

The network is intentionally independent from EC2 and EKS consumers. Compute reads network remote state. Platform reads network and compute remote state.

This separation is important for reliable destruction because it prevents Terraform from trying to delete VPC resources while EC2/EKS still owns ENIs, security-group references, subnets or load-balancer resources.

## 2. Two-AZ network standard

All three environments use the same HA pattern:

- 2 Availability Zones
- 2 public subnets
- 2 private subnets
- 2 NAT Gateways
- 1 NAT Gateway per AZ
- each private route table uses the NAT Gateway in the same AZ

There is no `single_nat_gateway` switch in the final version. This prevents dev/test from accidentally falling back to a single-NAT topology.

## 3. Environment CIDRs

### DEV

- VPC: `10.0.0.0/16`
- Public 1: `10.0.1.0/24`
- Public 2: `10.0.2.0/24`
- Private 1: `10.0.3.0/24`
- Private 2: `10.0.4.0/24`

### TEST

- VPC: `10.10.0.0/16`
- Public 1: `10.10.1.0/24`
- Public 2: `10.10.2.0/24`
- Private 1: `10.10.3.0/24`
- Private 2: `10.10.4.0/24`

### PROD

- VPC: `10.20.0.0/16`
- Public 1: `10.20.1.0/24`
- Public 2: `10.20.2.0/24`
- Private 1: `10.20.3.0/24`
- Private 2: `10.20.4.0/24`

## 4. Terraform state

Bootstrap creates independent state buckets for network, compute and platform. Environment separation is provided by different keys inside the layer bucket.

Native S3 locking is enabled with `use_lockfile = true`.

State objects are encrypted with KMS. Bucket versioning is enabled to allow recovery of previous state-object versions.

## 5. Provision order

Run bootstrap once for the AWS account.

Then, for each environment:

1. network
2. compute
3. platform

Example:

`./scripts/apply-environment.ps1 -Environment prod`

## 6. Destroy order

Always destroy in reverse order:

1. platform
2. compute
3. network

Example:

`./scripts/destroy-environment.ps1 -Environment prod`

Do not destroy bootstrap during routine environment rebuilds.

## 7. Why the reverse order matters

Platform owns EKS, EKS managed nodes, add-ons, ECR and application S3.

Compute owns Bastion/Admin EC2, Jenkins/SonarQube EC2, compute IAM roles, instance profiles and EC2 security groups.

Network owns VPC, Internet Gateway, NAT Gateways, EIPs, route tables, VPC endpoints, VPC Flow Logs and subnets.

Deleting platform first removes the EKS node groups and EKS-created networking dependencies while the VPC is still available.

Deleting compute second removes instances and security-group attachments while the subnets/VPC still exist.

Deleting network last allows NAT Gateways, endpoints, routes, subnets and the VPC to be deleted without active consumers.

## 8. Security baseline

- administrator ingress is restricted by CIDR
- EKS public API endpoint rejects `0.0.0.0/0` through variable validation
- EKS private endpoint is enabled
- worker nodes are private
- IMDSv2 is required
- EC2 and EKS node root volumes are encrypted
- Terraform state, EKS secrets, ECR and application S3 use KMS
- S3 public access is blocked
- VPC Flow Logs are enabled
- EKS control-plane logs are enabled
- SSM is enabled on EC2 and EKS nodes

## 9. Remote-state safety

The compute root verifies that the network state has the same project, environment and region.

The platform root verifies both network and compute remote states before applying.

This helps prevent accidentally using dev network state while deploying test/prod resources.

## 10. Existing infrastructure migration warning

The VPC module in this final version uses Availability Zone keys for stable resource identity and always creates one NAT per AZ.

If an older live state used count-based addresses or a single NAT, do not apply this package blindly against that state. Review the plan carefully. A clean rebuild is simplest for a lab/rebuild workflow. For a live production migration, use controlled Terraform state moves/imports and change windows.

## 11. Pre-apply checklist

- `aws sts get-caller-identity` returns the expected account
- backend KMS alias ARNs match the account
- bootstrap state buckets exist
- administrator CIDRs are correct
- EC2 key pair exists when SSH is required
- `terraform fmt -check` passes
- `terraform validate` passes
- `terraform plan` contains only intended changes

## 12. Post-EKS checks

After platform apply:

`aws eks update-kubeconfig --region us-east-1 --name openhelp-prod-eks`

`kubectl get nodes -o wide`

`kubectl get pods -A`

`aws eks describe-cluster --name openhelp-prod-eks --region us-east-1 --query "cluster.resourcesVpcConfig"`

Check that nodes have private IPs and are distributed across both private subnets/AZs.

## 13. State-lock recovery

Do not delete `.tflock` objects during a normal active Terraform run.

If a previous run terminated abnormally, first verify no Terraform process is still active. Use Terraform's normal force-unlock/recovery procedure only after confirming the lock is stale.
