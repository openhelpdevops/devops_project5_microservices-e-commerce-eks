project_name = "openhelp"
environment  = "test"
region       = "us-east-1"

vpc_cidr = "10.10.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs = ["10.10.1.0/24", "10.10.2.0/24"]
private_subnet_cidrs = ["10.10.3.0/24", "10.10.4.0/24"]
enable_vpc_endpoints = true
enable_vpc_flow_logs = true
vpc_flow_log_retention_days = 60
