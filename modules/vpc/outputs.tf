output "vpc_id" {
  value = aws_vpc.this.id
}

output "vpc_cidr" {
  value = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  value = [for az in var.availability_zones : aws_subnet.public[az].id]
}

output "private_subnet_ids" {
  value = [for az in var.availability_zones : aws_subnet.private[az].id]
}

output "nat_gateway_ids" {
  value = [for az in var.availability_zones : aws_nat_gateway.this[az].id]
}

output "nat_gateway_public_ips" {
  value = [for az in var.availability_zones : aws_eip.nat[az].public_ip]
}

output "public_route_table_id" {
  value = aws_route_table.public.id
}

output "private_route_table_ids" {
  value = [for az in var.availability_zones : aws_route_table.private[az].id]
}

output "vpc_endpoint_ids" {
  value = concat(
    [for endpoint in values(aws_vpc_endpoint.interface) : endpoint.id],
    aws_vpc_endpoint.s3[*].id,
  )
}
