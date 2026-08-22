project_name = "openhelp"
environment  = "test"
region       = "us-east-1"

cluster_version              = "1.36"
endpoint_public_access       = true
endpoint_private_access      = true
# IMPORTANT: replace this documentation/test CIDR with your approved public administrator CIDR.
public_access_cidrs           = ["217.119.64.63/32"]
cluster_deletion_protection  = false # allows clean terraform destroy; enable only if you accept a separate protection-disable step
cluster_log_retention_days   = 60

node_instance_types    = ["t3.medium"]
node_capacity_type     = "ON_DEMAND"
node_desired_size      = 2
node_min_size          = 1
node_max_size          = 4
node_disk_size         = 80
node_disk_iops         = 3000
node_disk_throughput   = 125

# Optional additional IAM role/user ARNs that should receive cluster-admin access.
cluster_admin_principal_arns = []


# Application container repositories managed by the platform layer.
ecr_repository_names = [
  "openhelp/test/adservice",
  "openhelp/test/cartservice",
  "openhelp/test/checkoutservice",
  "openhelp/test/currencyservice",
  "openhelp/test/emailservice",
  "openhelp/test/frontend",
  "openhelp/test/loadgenerator",
  "openhelp/test/paymentservice",
  "openhelp/test/productcatalogservice",
  "openhelp/test/recommendationservice",
  "openhelp/test/shippingservice",
]

ecr_force_delete = true
ecr_untagged_retention_days   = 30
ecr_tagged_image_count        = 50

# Two protected application/project S3 buckets.
application_bucket_force_destroy = true
application_bucket_noncurrent_retention_days = 60

enable_node_ssm = true

# AWS Load Balancer Controller is part of the EKS/platform lifecycle.
enable_aws_load_balancer_controller             = true
aws_load_balancer_controller_chart_version       = "3.5.0"
aws_load_balancer_controller_replica_count       = 2
enable_aws_load_balancer_controller_pdb          = false
