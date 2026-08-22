# Production Readiness and Destroy-Safety Audit

Audit date: 2026-08-22  
Scope: bootstrap, Terraform modules, dev/test/prod roots, Kubernetes manifests,
AWS Load Balancer Controller, Argo CD deployment path, Jenkinsfiles, and teardown.

## Executive result

The infrastructure is organized into reusable modules and three intentionally
separate state layers per environment. Those dependencies must not be removed:
they encode the correct build order (`network -> compute -> platform`) and the
correct destroy order (`platform -> compute -> network`).

The original destroy process was not safe for Kubernetes-created AWS load
balancers. Terraform did not own the application's `LoadBalancer` Service, so it
could remove the controller and EKS cluster before the NLB, target groups and
security-group rules were released. Those orphaned resources can block subnet,
internet-gateway, security-group and VPC deletion.

The corrected teardown now fails closed: it prunes Argo CD applications, deletes
remaining `LoadBalancer` Services and Ingresses, waits for TargetGroupBinding
finalizers, and only then destroys platform, compute and network states.

## Verified architecture

| Area | Result | Notes |
|---|---|---|
| Terraform module layout | Pass | Shared VPC, EC2, IAM, EKS, ECR and S3 modules are reused by all environments. |
| Environment isolation | Pass | Dev, test and prod use different state keys, VPC CIDRs and resource names. |
| Apply ordering | Pass | Network state feeds compute; network and compute states feed platform. |
| Destroy ordering | Fixed | Controlled cleanup now precedes platform, compute and network destruction. |
| EKS node placement | Pass | Managed nodes use private subnets in two Availability Zones. |
| Public NLB subnet discovery | Pass | Public subnets have `kubernetes.io/role/elb=1`; no subnet IDs are hard-coded in application YAML. |
| Internal LB subnet discovery | Pass | Private subnets have `kubernetes.io/role/internal-elb=1`. |
| AWS Load Balancer Controller | Pass (static) | Helm release, IRSA trust, role annotation, region, VPC ID, two replicas and PDB are wired together. |
| Argo CD deployment path | Added | A production Application targets `kubernetes-files`, enables prune/self-heal and uses a deletion finalizer. |
| NLB manifest | Pass (static) | `LoadBalancer`, `service.k8s.aws/nlb`, external controller selection, IP targets, health check and tags are present. |
| Kubernetes availability | Improved | Stateless services use two replicas, zero-unavailable rolling updates and zone spreading. |
| YAML syntax | Pass | Every YAML document parsed successfully. |
| Terraform runtime validation | Not executed here | Run the validation matrix below from a host with Terraform and registry access. |
| Live AWS/Argo CD/NLB test | Not executed here | Requires AWS credentials, deployed states, EKS API access and the real repository connection. |

## Important retained dependencies

Terraform dependencies are not defects. They prevent race conditions and make
reverse-order deletion predictable:

1. NAT gateways depend on the internet gateway.
2. EKS depends on its IAM roles and control-plane log group.
3. Managed nodes depend on the VPC CNI add-on.
4. CoreDNS, kube-proxy and Pod Identity depend on nodes being available.
5. The AWS Load Balancer Controller Helm release depends on EKS and its IRSA role.
6. Compute reads network outputs; platform reads network and compute outputs.

## Controlled deployment

Apply each state in dependency order:

```powershell
./scripts/apply-environment.ps1 -Environment dev
./scripts/apply-environment.ps1 -Environment test
./scripts/apply-environment.ps1 -Environment prod
```

After Argo CD itself is installed and connected to the repository:

```powershell
kubectl apply -f ./argocd/online-boutique-prod.yaml
kubectl -n argocd get application online-boutique-prod
kubectl -n kube-system rollout status deployment/aws-load-balancer-controller --timeout=5m
kubectl get service frontend-external -w
```

Expected result: `frontend-external` receives an AWS NLB DNS name. Confirm that
the target group contains healthy Pod IP targets before directing production
DNS to the NLB.

## Controlled destruction

Run from a host with Terraform, AWS CLI, kubectl, access to all three S3 states,
and network access to the EKS API:

```powershell
./scripts/destroy-environment.ps1 -Environment dev
./scripts/destroy-environment.ps1 -Environment test
./scripts/destroy-environment.ps1 -Environment prod
```

Use `-AutoApprove` only in an approved automation pipeline. The script stops on
the first cleanup or Terraform failure and will not continue into a dependency
layer. It intentionally does not strip Kubernetes finalizers because doing so
can orphan AWS resources.

## Required validation matrix before release

Run this for every environment and layer:

```powershell
$environments = @("dev", "test", "prod")
$layers = @("network", "compute", "platform")
foreach ($environment in $environments) {
  foreach ($layer in $layers) {
    Push-Location "./environments/$environment/$layer"
    terraform init -reconfigure -input=false
    terraform fmt -check -recursive
    terraform validate
    terraform plan -input=false -lock-timeout=5m
    Pop-Location
  }
}
```

A production release also requires a real apply/smoke/destroy test in a
disposable AWS environment.

## Remaining production gaps

These items are outside the load-balancer/destroy correction and must not be
hidden behind a claim of complete production readiness:

1. `redis-cart` uses ephemeral storage. Use ElastiCache/MemoryDB or a supported
   persistent Redis design before treating cart data as durable.
2. Jenkins and SonarQube share one mutable EC2 host and install from live
   internet repositories during boot. A hardened production CI platform needs
   immutable images, backups, TLS, separate persistence and controlled upgrades.
3. Jenkinsfiles and Kubernetes images are hard-coded to one AWS account,
   `us-east-1`, and the `prod` ECR path. Add environment overlays before using
   the same GitOps path for dev and test application deployments.
4. Application images use numeric tags, not immutable digests. Production GitOps
   should promote tested image digests between environments.
5. The public service is HTTP-only. Add ACM-backed TLS and DNS before exposing
   real user or payment traffic.
6. The repository does not install Argo CD itself. Its lifecycle and recovery
   procedure must be managed separately.
7. There are no NetworkPolicies, autoscalers, application PDBs, centralized
   alert rules, SLOs, or disaster-recovery tests in this repository.
8. Production cluster/EC2 deletion protection is disabled and ECR/S3 force
   deletion is enabled for one-command teardown. Long-lived production normally
   uses protection plus a separately approved break-glass teardown procedure.

## Acceptance checks

Before approving release, capture evidence for all of these:

- Terraform plan contains only intended resources in each environment.
- AWS Load Balancer Controller has two available replicas and no IAM errors.
- Argo CD reports the production application `Synced` and `Healthy`.
- NLB spans both public subnets and has healthy Pod IP targets.
- The frontend health endpoint returns HTTP 200 through the NLB.
- Deleting the Argo CD Application removes its Service, NLB, target groups and
  TargetGroupBindings before EKS teardown.
- A disposable full destroy leaves no project-tagged ELB, target group, ENI,
  security group, NAT gateway, subnet or VPC resource.
