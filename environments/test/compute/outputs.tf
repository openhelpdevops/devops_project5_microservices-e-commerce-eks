output "project_name" { value = var.project_name }
output "environment" { value = var.environment }
output "region" { value = var.region }
output "bastion_instance_id" { value = module.ec2.bastion_instance_id }
output "bastion_public_ip" { value = module.ec2.bastion_public_ip }
output "tools_instance_id" { value = module.ec2.tools_instance_id }
output "tools_public_ip" { value = module.ec2.tools_public_ip }
output "tools_private_ip" { value = module.ec2.tools_private_ip }
output "bastion_role_arn" { value = module.iam_compute.bastion_role_arn }
output "tools_role_arn" { value = module.iam_compute.tools_role_arn }
output "bastion_security_group_id" { value = module.security_group.bastion_security_group_id }
output "tools_security_group_id" { value = module.security_group.tools_security_group_id }
output "selected_ami_id" { value = module.ec2.selected_ami_id }
output "bastion_ssh_command" {
  value = module.ec2.bastion_public_ip == null || var.key_name == "" ? null : "ssh -i ${var.key_name}.pem ubuntu@${module.ec2.bastion_public_ip}"
}
output "tools_ssh_command" {
  value = module.ec2.tools_public_ip == null || var.key_name == "" ? null : "ssh -i ${var.key_name}.pem ubuntu@${module.ec2.tools_public_ip}"
}
