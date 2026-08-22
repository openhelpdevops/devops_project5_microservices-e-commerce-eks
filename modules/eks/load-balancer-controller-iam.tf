# -----------------------------------------------------------------------------
# AWS Load Balancer Controller IRSA
# -----------------------------------------------------------------------------
# IAM/IRSA for the AWS Load Balancer Controller is kept with the EKS module
# because its trust policy is bound directly to this cluster's OIDC provider.
# The Helm release is managed by the existing platform root stack so cluster,
# IAM and controller lifecycle remain in one Terraform state without a separate
# addons layer. The policy is vendored so apply does not depend on GitHub.
resource "aws_iam_policy" "aws_load_balancer_controller" {
  name        = "${var.cluster_name}-aws-load-balancer-controller"
  description = "AWS Load Balancer Controller permissions for ${var.cluster_name}"
  policy      = file("${path.module}/policies/aws-load-balancer-controller-v3.5.0.json")
  tags        = var.tags
}

data "aws_iam_policy_document" "aws_load_balancer_controller_assume" {
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
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "aws_iam_role" "aws_load_balancer_controller" {
  name               = "${var.cluster_name}-aws-lbc-role"
  assume_role_policy = data.aws_iam_policy_document.aws_load_balancer_controller_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
}
