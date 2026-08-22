# -----------------------------------------------------------------------------
# AWS Load Balancer Controller
# -----------------------------------------------------------------------------
# Managed in the existing EKS/platform state. IAM/IRSA is created by module.eks;
# this Helm release installs the in-cluster controller only after EKS is ready.
# No subnet IDs are hard-coded here or in application YAML. The controller uses
# the Terraform-managed kubernetes.io/role/elb and internal-elb subnet tags.
resource "helm_release" "aws_load_balancer_controller" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.aws_load_balancer_controller_chart_version
  namespace  = "kube-system"

  atomic          = true
  cleanup_on_fail = true
  wait            = true
  timeout         = 900

  values = [
    yamlencode({
      clusterName = module.eks.cluster_name

      # Required because worker IMDS is intentionally restricted to hop limit 1.
      # Values come from Terraform state, not from hard-coded application YAML.
      region = var.region
      vpcId  = data.terraform_remote_state.network.outputs.vpc_id

      replicaCount = var.aws_load_balancer_controller_replica_count

      resources = {
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
        limits = {
          cpu    = "500m"
          memory = "256Mi"
        }
      }

      podDisruptionBudget = var.enable_aws_load_balancer_controller_pdb ? tomap({
        maxUnavailable = 1
      }) : tomap({})

      serviceAccount = {
        create = true
        name   = "aws-load-balancer-controller"
        annotations = {
          "eks.amazonaws.com/role-arn" = module.eks.aws_load_balancer_controller_role_arn
        }
      }

      enableServiceMutatorWebhook = true

      defaultTags = {
        Project     = var.project_name
        Environment = var.environment
        ManagedBy   = "aws-load-balancer-controller"
      }
    })
  ]

  depends_on = [module.eks]
}
