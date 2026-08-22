param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("dev", "test", "prod")]
  [string]$Environment
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot

foreach ($Layer in @("network", "compute", "platform")) {
  $Path = Join-Path $Root "environments/$Environment/$Layer"
  Write-Host "=== APPLY $Environment / $Layer ===" -ForegroundColor Cyan
  Push-Location $Path
  try {
    terraform init -reconfigure
    terraform fmt -check
    terraform validate
    terraform plan -out=tfplan
    terraform apply tfplan
    Remove-Item tfplan -ErrorAction SilentlyContinue
  }
  finally {
    Pop-Location
  }
}
