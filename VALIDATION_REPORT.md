# Validation Report - AWS EKS Load Balancer Production Fix

## Scope reviewed

The bundle was scanned across:

- bootstrap remote-state foundation
- dev/test/prod network layers
- dev/test/prod compute layers
- dev/test/prod platform layers
- shared VPC/EKS/IAM modules
- Kubernetes manifests
- Jenkins files for ECR/GitOps compatibility impact
- apply/destroy ordering and documentation

## Root cause confirmed in code

The existing EKS module already created an IAM OIDC provider, and the VPC module already tagged public/private subnets correctly for Kubernetes load-balancer discovery. The missing infrastructure component was the AWS Load Balancer Controller itself and its dedicated controller IAM role/policy.

The frontend manifest also had stale settings that were inconsistent with the repository:

- hard-coded `dev` namespace while the other application manifests use the default namespace
- `nexus-secret` image pull secret after images had moved to Amazon ECR
- no AWS Load Balancer Controller ownership/class or NLB settings

## Changes validated

- Added a dedicated IRSA role trusted only by `system:serviceaccount:kube-system:aws-load-balancer-controller`.
- Added the controller IAM policy vendored from the official AWS Load Balancer Controller v3.5.0 policy.
- Integrated the AWS Load Balancer Controller into the existing `platform` Terraform state.
- Pinned the AWS Load Balancer Controller Helm chart to `3.5.0`.
- Configured Helm with cluster endpoint/CA from platform remote state and short-lived `aws eks get-token` authentication.
- Passed VPC ID and region dynamically from Terraform state because worker IMDS is restricted to hop limit 1.
- Kept two controller replicas; enabled a PDB only in prod.
- Kept subnet discovery dynamic through Terraform-managed subnet tags; no subnet IDs were added to application YAML.
- Updated `frontend-external` to an internet-facing NLB with IP targets and HTTP `/_healthz` target checks.
- Kept apply/destroy scripts at the original network -> compute -> platform lifecycle.
- Preserved existing project documents and added a dedicated production load-balancer guide.

## Static validation executed in this workspace

- Parsed every `kubernetes-files/*.yaml` document successfully with a YAML parser.
- Parsed the vendored controller IAM policy successfully as JSON.
- Performed balanced-delimiter checks across all Terraform `.tf` files.
- Confirmed no `namespace: dev`, `nexus-secret`, or hard-coded `aws-load-balancer-subnets` remains in `kubernetes-files/frontend.yaml`.
- Confirmed public subnet tags remain `kubernetes.io/role/elb=1` and private subnet tags remain `kubernetes.io/role/internal-elb=1`.
- Confirmed public route tables still route `0.0.0.0/0` to the Internet Gateway.
- Confirmed EKS workers remain in private subnets and VPC CNI is enabled for VPC-native Pod IP targets.

## Runtime validation required after download

The execution environment used to prepare this bundle does not contain the Terraform binary or access to your AWS account, so provider-level `terraform init/validate/plan` and live AWS reconciliation could not be executed here.

Run these in order in your AWS-authenticated environment:

```text
environments/prod/platform
  terraform init -reconfigure
  terraform fmt -check
  terraform validate
  terraform plan
  terraform apply
```

Then verify:

```bash
kubectl get deployment aws-load-balancer-controller -n kube-system
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
kubectl delete service frontend-external --ignore-not-found
kubectl apply -f kubernetes-files/frontend.yaml
kubectl get service frontend-external -w
```

If reconciliation fails, the authoritative diagnostics are:

```bash
kubectl describe service frontend-external
kubectl logs -n kube-system deployment/aws-load-balancer-controller --tail=200
kubectl get targetgroupbinding -A
```

## Upgrade note

The controller version is intentionally pinned. Do not change the chart version without reviewing the corresponding controller release notes, IAM policy, and CRD update requirements. Helm installs chart CRDs on first install, but CRD upgrades require explicit review when the controller version changes.

## Platform integration refactor

- Removed the temporary `environments/*/addons` and `modules/eks-addons` structure.
- AWS Load Balancer Controller IAM/IRSA remains cluster-bound in `modules/eks`.
- Helm release is managed from `environments/*/platform/load-balancer-controller.tf`.
- No subnet IDs are hard-coded into frontend YAML; subnet discovery continues to use VPC tags.
- Production enables two controller replicas and a PDB.
