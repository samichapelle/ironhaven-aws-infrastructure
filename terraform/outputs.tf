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
    public                 = aws_subnet.public.id
    private_app            = aws_subnet.private_app.id
    private_data           = aws_subnet.private_data.id
    private_data_secondary = aws_subnet.private_data_secondary.id
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

output "management_instance_id" {
  description = "ID of the SSM-managed EC2 instance."
  value       = aws_instance.management.id
}

output "ansible_transfer_bucket_name" {
  description = "Name of the private S3 bucket used for temporary Ansible transfers."
  value       = aws_s3_bucket.ansible_transfer.id
}

output "database" {
  description = "Connection metadata for the private PostgreSQL database."

  value = {
    identifier = aws_db_instance.postgresql.identifier
    address    = aws_db_instance.postgresql.address
    port       = aws_db_instance.postgresql.port
    name       = aws_db_instance.postgresql.db_name
    username   = aws_db_instance.postgresql.username
  }
}

output "database_master_secret_arn" {
  description = "ARN of the AWS-managed Secrets Manager secret containing the PostgreSQL master credentials."
  value       = aws_db_instance.postgresql.master_user_secret[0].secret_arn
}
