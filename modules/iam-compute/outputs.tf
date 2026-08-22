output "bastion_instance_profile_name" { value = aws_iam_instance_profile.bastion.name }
output "bastion_role_arn" { value = aws_iam_role.bastion.arn }
output "tools_instance_profile_name" { value = aws_iam_instance_profile.tools.name }
output "tools_role_arn" { value = aws_iam_role.tools.arn }
