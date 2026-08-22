output "bastion_instance_id" { value = try(aws_instance.bastion[0].id, null) }
output "bastion_public_ip" { value = try(aws_instance.bastion[0].public_ip, null) }
output "tools_instance_id" { value = try(aws_instance.tools[0].id, null) }
output "tools_private_ip" { value = try(aws_instance.tools[0].private_ip, null) }
output "tools_public_ip" { value = try(aws_instance.tools[0].public_ip, null) }
output "selected_ami_id" { value = local.selected_ami_id }
