project_name = "openhelp"
environment  = "prod"
region       = "us-east-1"

vpc_cidr = "10.20.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs = ["10.20.1.0/24", "10.20.2.0/24"]
private_subnet_cidrs = ["10.20.3.0/24", "10.20.4.0/24"]
enable_vpc_endpoints = true
enable_vpc_flow_logs = true
vpc_flow_log_retention_days = 90
