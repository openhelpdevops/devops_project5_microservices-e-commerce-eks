param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("dev", "test", "prod")]
  [string]$Environment,

  [switch]$AutoApprove
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Region = "us-east-1"
$ClusterName = "openhelp-$Environment-eks"
$PlatformPath = Join-Path $Root "environments/$Environment/platform"

function Invoke-TerraformDestroy {
  param([Parameter(Mandatory = $true)][string]$Layer)

  $Path = Join-Path $Root "environments/$Environment/$Layer"
  Write-Host "=== DESTROY $Environment / $Layer ===" -ForegroundColor Yellow
  Push-Location $Path
  try {
    terraform init -reconfigure -input=false
    terraform validate

    $Arguments = @("destroy", "-input=false")
    if ($AutoApprove) {
      $Arguments += "-auto-approve"
    }

    & terraform @Arguments
    if ($LASTEXITCODE -ne 0) {
      throw "Terraform destroy failed for layer '$Layer'. Later layers were not destroyed."
    }
  }
  finally {
    Pop-Location
  }
}

function Remove-KubernetesLoadBalancers {
  Write-Host "=== PRE-DESTROY KUBERNETES AND ELB CLEANUP ===" -ForegroundColor Yellow

  # If platform state is already gone, there is no EKS API to clean.
  Push-Location $PlatformPath
  try {
    terraform init -reconfigure -input=false | Out-Null
    $StateResources = terraform state list 2>$null
  }
  finally {
    Pop-Location
  }

  if (-not ($StateResources -match '^module\.eks\.aws_eks_cluster\.this$')) {
    Write-Host "EKS cluster is not present in platform state; skipping Kubernetes cleanup."
    return
  }

  foreach ($Command in @("aws", "kubectl")) {
    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
      throw "'$Command' is required to clean Kubernetes-managed AWS load balancers before EKS/VPC deletion."
    }
  }

  aws eks update-kubeconfig --name $ClusterName --region $Region | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Unable to configure kubectl for '$ClusterName'. Refusing to destroy EKS before ELB cleanup."
  }

  kubectl cluster-info --request-timeout=30s | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "The EKS API is unreachable. Run this command from a host that can reach the cluster endpoint."
  }

  # Cascading Argo CD deletion prunes workloads and lets the AWS controller
  # process its finalizers while the controller and cluster are still alive.
  $ArgoApi = kubectl api-resources --api-group=argoproj.io -o name 2>$null
  if ($ArgoApi -contains "applications.argoproj.io") {
    $Applications = kubectl get applications.argoproj.io -A -o name 2>$null
    if ($Applications) {
      kubectl delete applications.argoproj.io --all -A --cascade=foreground --wait=true --timeout=15m
      if ($LASTEXITCODE -ne 0) {
        throw "Argo CD application pruning failed. EKS was not destroyed."
      }
    }
  }

  # Also remove load balancers created outside Argo CD.
  $LoadBalancerServices = kubectl get services -A -o json | ConvertFrom-Json |
    Select-Object -ExpandProperty items |
    Where-Object { $_.spec.type -eq "LoadBalancer" }

  foreach ($Service in @($LoadBalancerServices)) {
    kubectl delete service $Service.metadata.name -n $Service.metadata.namespace --wait=true --timeout=15m
    if ($LASTEXITCODE -ne 0) {
      throw "Failed to delete LoadBalancer Service '$($Service.metadata.namespace)/$($Service.metadata.name)'. EKS was not destroyed."
    }
  }

  $Ingresses = kubectl get ingress -A -o name 2>$null
  if ($Ingresses) {
    kubectl delete ingress --all -A --wait=true --timeout=15m
    if ($LASTEXITCODE -ne 0) {
      throw "Failed to delete one or more Ingress resources. EKS was not destroyed."
    }
  }

  # The controller removes TargetGroupBinding finalizers only after AWS cleanup.
  $Deadline = (Get-Date).AddMinutes(20)
  do {
    $RemainingServices = kubectl get services -A -o json | ConvertFrom-Json |
      Select-Object -ExpandProperty items |
      Where-Object { $_.spec.type -eq "LoadBalancer" }
    $RemainingIngresses = kubectl get ingress -A -o name 2>$null
    $RemainingBindings = kubectl get targetgroupbindings.elbv2.k8s.aws -A -o name 2>$null

    if (-not $RemainingServices -and -not $RemainingIngresses -and -not $RemainingBindings) {
      Write-Host "Kubernetes-managed AWS load balancers have been released." -ForegroundColor Green
      return
    }

    if ((Get-Date) -ge $Deadline) {
      throw "Timed out waiting for ELB cleanup. EKS and VPC were not destroyed. Investigate controller logs and finalizers."
    }

    Write-Host "Waiting for AWS load balancer finalizers to complete..."
    Start-Sleep -Seconds 15
  } while ($true)
}

# AWS requires LoadBalancer Services and Ingresses to be removed before EKS.
Remove-KubernetesLoadBalancers

# Separate Terraform states must be destroyed in reverse dependency order.
foreach ($Layer in @("platform", "compute", "network")) {
  Invoke-TerraformDestroy -Layer $Layer
}
