# AWS Load Balancer Controller - Production EKS Integration

This repository manages the AWS Load Balancer Controller inside the existing EKS **platform** Terraform stack. There is no separate `addons` layer or state.

## Design

```text
network -> compute -> platform
                      |
                      +-- EKS cluster
                      +-- EKS OIDC provider
                      +-- AWS LBC IAM policy + IRSA role
                      +-- AWS Load Balancer Controller Helm release
```

The IAM/OIDC resources remain in `modules/eks` because the IRSA trust relationship is specific to the EKS cluster OIDC provider. The Helm release is in `environments/<env>/platform/load-balancer-controller.tf`, which keeps it in the same platform state while avoiding a child-module provider dependency cycle.

## No subnet IDs in application YAML

Public and private subnets are selected by AWS Load Balancer Controller subnet discovery. Terraform already manages these tags in `modules/vpc`:

- Public: `kubernetes.io/role/elb = 1`
- Private: `kubernetes.io/role/internal-elb = 1`

`kubernetes-files/frontend.yaml` therefore does not contain environment-specific subnet IDs.

## IRSA

Terraform creates the cluster IAM OIDC provider and a dedicated role trusted only by:

```text
system:serviceaccount:kube-system:aws-load-balancer-controller
```

The official controller IAM policy is vendored under `modules/eks/policies/` so an apply is not dependent on GitHub availability.

## Restricted IMDS

EKS worker instances use IMDSv2 with hop limit 1. Therefore the Helm chart receives `region` and `vpcId` explicitly from Terraform values/state. Nothing is hard-coded in the frontend manifest.

## Apply

Run the normal platform stack:

```bash
cd environments/prod/platform
terraform init -reconfigure
terraform fmt -check
terraform validate
terraform plan
terraform apply
```

The Terraform runner must have network connectivity to the EKS API endpoint and AWS CLI available because the Helm provider uses `aws eks get-token`. For a private EKS endpoint, run it from the bastion/tools host or a CI runner inside the VPC.

## Verify

```bash
kubectl get deployment aws-load-balancer-controller -n kube-system
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

Expected production deployment is two replicas.

Recreate an old LoadBalancer Service that was created before the controller existed:

```bash
kubectl delete svc frontend-external --ignore-not-found
kubectl apply -f kubernetes-files/frontend.yaml
kubectl get svc frontend-external -w
```

## Destroy order

The normal reverse order remains:

```text
platform -> compute -> network
```

Because the Helm release and EKS cluster are in the same platform state, Terraform's dependency graph destroys the controller release before destroying the EKS resources it depends on.
