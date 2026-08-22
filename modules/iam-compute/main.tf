data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  eks_cluster_arn = "arn:${data.aws_partition.current.partition}:eks:${var.region}:${data.aws_caller_identity.current.account_id}:cluster/${var.eks_cluster_name}"
  ecr_repo_arns   = ["arn:${data.aws_partition.current.partition}:ecr:${var.region}:${data.aws_caller_identity.current.account_id}:repository/${var.project_name}/${var.environment}/*"]
}

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "bastion" {
  name               = "${var.project_name}-${var.environment}-bastion-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
  tags               = var.tags
}
resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_role_policy" "bastion_read" {
  name = "${var.project_name}-${var.environment}-bastion-read"
  role = aws_iam_role.bastion.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Sid = "DescribeEKS", Effect = "Allow", Action = ["eks:DescribeCluster"], Resource = local.eks_cluster_arn },
      { Sid = "ReadEC2", Effect = "Allow", Action = ["ec2:DescribeInstances", "ec2:DescribeSecurityGroups", "ec2:DescribeNetworkInterfaces", "ec2:DescribeSubnets", "ec2:DescribeVpcs"], Resource = "*" }
    ]
  })
}
resource "aws_iam_instance_profile" "bastion" {
  name = "${var.project_name}-${var.environment}-bastion-profile"
  role = aws_iam_role.bastion.name
}

resource "aws_iam_role" "tools" {
  name               = "${var.project_name}-${var.environment}-tools-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
  tags               = var.tags
}
resource "aws_iam_role_policy_attachment" "tools_ssm" {
  role       = aws_iam_role.tools.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_role_policy" "tools_platform" {
  name = "${var.project_name}-${var.environment}-tools-platform"
  role = aws_iam_role.tools.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Sid = "DescribeEKS", Effect = "Allow", Action = ["eks:DescribeCluster"], Resource = local.eks_cluster_arn },
      { Sid = "ECRLogin", Effect = "Allow", Action = ["ecr:GetAuthorizationToken"], Resource = "*" },
      {
        Sid = "PushPullApplicationImages", Effect = "Allow",
        Action = ["ecr:BatchCheckLayerAvailability", "ecr:BatchGetImage", "ecr:CompleteLayerUpload", "ecr:GetDownloadUrlForLayer", "ecr:InitiateLayerUpload", "ecr:ListImages", "ecr:PutImage", "ecr:UploadLayerPart", "ecr:DescribeImages", "ecr:DescribeRepositories"],
        Resource = local.ecr_repo_arns
      }
    ]
  })
}
resource "aws_iam_instance_profile" "tools" {
  name = "${var.project_name}-${var.environment}-tools-profile"
  role = aws_iam_role.tools.name
}
