output "aws_region" {
  description = "AWS region containing the Ironhaven infrastructure."
  value       = var.aws_region
}

output "vpc_id" {
  description = "ID of the Ironhaven VPC."
  value       = aws_vpc.main.id
}

output "subnet_ids" {
  description = "IDs of the public, application and data subnets."

  value = {
    public       = aws_subnet.public.id
    private_app  = aws_subnet.private_app.id
    private_data = aws_subnet.private_data.id
  }
}

output "security_group_ids" {
  description = "IDs of the management, application and data security groups."

  value = {
    management  = aws_security_group.management.id
    application = aws_security_group.application.id
    data        = aws_security_group.data.id
  }
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway attached to the VPC."
  value       = aws_internet_gateway.main.id
}

output "public_route_table_id" {
  description = "ID of the public route table."
  value       = aws_route_table.public.id
}