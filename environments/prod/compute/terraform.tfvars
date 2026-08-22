project_name = "openhelp"
environment  = "prod"
region       = "us-east-1"

admin_cidr_blocks = ["217.119.64.150/32"]
ami_id = ""
key_name = "openhelp-key"
create_bastion = true
create_tools_host = true
bastion_instance_type = "m7i-flex.large"
tools_instance_type = "m7i-flex.large"
termination_protection = false
# false intentionally: clean Terraform destroy without manual EC2 protection changes
detailed_monitoring = true
bastion_root_volume_size = 30
tools_root_volume_size = 100
