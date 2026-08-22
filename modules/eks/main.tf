data "aws_partition" "current" {}

data "tls_certificate" "eks_oidc" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_kms_key" "eks" {
  description             = "KMS key for ${var.cluster_name} Kubernetes secrets"
  deletion_window_in_days = 30
  enable_key_rotation     = true
tags = merge(var.tags, { Name = "${var.cluster_name}-kms", Critical = "true" })
}
resource "aws_kms_alias" "eks" {
  name          = "alias/${var.cluster_name}"
  target_key_id = aws_kms_key.eks.key_id
}

resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.cluster_log_retention_days
  tags              = merge(var.tags, { Name = "${var.cluster_name}-control-plane-logs" })
}

resource "aws_eks_cluster" "this" {
  name                      = var.cluster_name
  role_arn                  = var.cluster_role_arn
  version                   = var.cluster_version
  deletion_protection       = var.cluster_deletion_protection

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  encryption_config {
    resources = ["secrets"]
    provider { key_arn = aws_kms_key.eks.arn }
  }

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_public_access  = var.endpoint_public_access
    endpoint_private_access = var.endpoint_private_access
    public_access_cidrs     = var.public_access_cidrs
  }
tags = merge(var.tags, { Name = var.cluster_name, Critical = "true" })
  depends_on = [aws_cloudwatch_log_group.eks]
  timeouts {
    create = "45m"
    update = "60m"
    delete = "60m"
  }
}

resource "aws_vpc_security_group_ingress_rule" "bastion_to_api" {
  count                        = var.bastion_security_group_id != "" ? 1 : 0
  security_group_id            = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  referenced_security_group_id = var.bastion_security_group_id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "Bastion access to private EKS API"
}

resource "aws_vpc_security_group_ingress_rule" "tools_to_api" {
  count                        = var.tools_security_group_id != "" ? 1 : 0
  security_group_id            = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  referenced_security_group_id = var.tools_security_group_id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "Private tools host access to EKS API"
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  tags            = merge(var.tags, { Name = "${var.cluster_name}-oidc" })
}

data "aws_iam_policy_document" "vpc_cni_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-node"]
    }
  }
}
resource "aws_iam_role" "vpc_cni" {
  name               = "${var.project_name}-${var.environment}-vpc-cni-role"
  assume_role_policy = data.aws_iam_policy_document.vpc_cni_assume.json
  tags               = var.tags
}
resource "aws_iam_role_policy_attachment" "vpc_cni" {
  role       = aws_iam_role.vpc_cni.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "vpc-cni"
  service_account_role_arn    = aws_iam_role.vpc_cni.arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"
  depends_on                  = [aws_iam_role_policy_attachment.vpc_cni]
}

resource "aws_launch_template" "eks_nodes" {
  name_prefix            = "${var.cluster_name}-nodes-"
  update_default_version = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      encrypted             = true
      volume_type           = "gp3"
      volume_size           = var.node_disk_size
      iops                  = var.node_disk_iops
      throughput            = var.node_disk_throughput
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, { Name = "${var.cluster_name}-node", Critical = "true" })
  }
  tag_specifications {
    resource_type = "volume"
    tags = merge(var.tags, { Name = "${var.cluster_name}-node-volume" })
  }
  tags = var.tags
}

resource "aws_eks_node_group" "default" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.project_name}-${var.environment}-general"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = var.node_instance_types
  capacity_type   = var.node_capacity_type
  ami_type        = "AL2023_x86_64_STANDARD"

  launch_template {
    id      = aws_launch_template.eks_nodes.id
    version = aws_launch_template.eks_nodes.latest_version
  }

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  update_config { max_unavailable = 1 }
  labels = { workload = "general", environment = var.environment }

  lifecycle { ignore_changes = [scaling_config[0].desired_size] }
  tags = merge(var.tags, { Name = "${var.project_name}-${var.environment}-general", Critical = "true" })
  depends_on = [aws_eks_addon.vpc_cni]
  timeouts {
    create = "60m"
    update = "60m"
    delete = "60m"
  }
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"
  depends_on                  = [aws_eks_node_group.default]
}
resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "coredns"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"
  depends_on                  = [aws_eks_node_group.default]
}
resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "eks-pod-identity-agent"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"
  depends_on                  = [aws_eks_node_group.default]
}

data "aws_iam_policy_document" "pod_identity_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}
resource "aws_iam_role" "ebs_csi" {
  count              = var.enable_ebs_csi ? 1 : 0
  name               = "${var.project_name}-${var.environment}-ebs-csi-role"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume.json
  tags               = var.tags
}
resource "aws_iam_role_policy_attachment" "ebs_csi" {
  count      = var.enable_ebs_csi ? 1 : 0
  role       = aws_iam_role.ebs_csi[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEBSCSIDriverPolicyV2"
}
resource "aws_eks_pod_identity_association" "ebs_csi" {
  count           = var.enable_ebs_csi ? 1 : 0
  cluster_name    = aws_eks_cluster.this.name
  namespace       = "kube-system"
  service_account = "ebs-csi-controller-sa"
  role_arn        = aws_iam_role.ebs_csi[0].arn
  depends_on      = [aws_eks_addon.pod_identity_agent, aws_iam_role_policy_attachment.ebs_csi]
}
resource "aws_eks_addon" "ebs_csi" {
  count                       = var.enable_ebs_csi ? 1 : 0
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "aws-ebs-csi-driver"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"
  depends_on                  = [aws_eks_pod_identity_association.ebs_csi]
}

locals {
  base_access = merge(
    var.bastion_role_arn != "" ? { bastion = { arn = var.bastion_role_arn, policy = "AmazonEKSClusterAdminPolicy" } } : {},
    var.tools_role_arn != "" ? { tools = { arn = var.tools_role_arn, policy = "AmazonEKSEditPolicy" } } : {},
    { for arn in var.cluster_admin_principal_arns : replace(replace(arn, ":", "_"), "/", "_") => { arn = arn, policy = "AmazonEKSClusterAdminPolicy" } }
  )
}
resource "aws_eks_access_entry" "standard" {
  for_each      = local.base_access
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value.arn
  type          = "STANDARD"
}
resource "aws_eks_access_policy_association" "standard" {
  for_each      = local.base_access
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value.arn
  policy_arn    = "arn:${data.aws_partition.current.partition}:eks::aws:cluster-access-policy/${each.value.policy}"
  access_scope { type = "cluster" }
  depends_on = [aws_eks_access_entry.standard]
}
