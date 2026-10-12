resource "aws_db_subnet_group" "data" {
  name        = "${local.name_prefix}-data-subnet-group"
  description = "Private multi-AZ subnet group for the Ironhaven data tier"

  subnet_ids = [
    aws_subnet.private_data.id,
    aws_subnet.private_data_secondary.id,
  ]

  tags = {
    Name = "${local.name_prefix}-data-subnet-group"
    Tier = "data"
  }
}

resource "aws_db_instance" "postgresql" {
  identifier = "${local.name_prefix}-postgresql"

  engine                   = "postgres"
  engine_lifecycle_support = "open-source-rds-extended-support-disabled"
  instance_class           = var.database_instance_class

  allocated_storage     = var.database_allocated_storage
  max_allocated_storage = var.database_max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name                     = var.database_name
  username                    = var.database_master_username
  manage_master_user_password = true
  port                        = 5432

  db_subnet_group_name   = aws_db_subnet_group.data.name
  vpc_security_group_ids = [aws_security_group.data.id]
  publicly_accessible    = false
  network_type           = "IPV4"
  multi_az               = false

  iam_database_authentication_enabled = true

  backup_retention_period = 1
  backup_window           = "02:00-02:30"
  maintenance_window      = "sun:03:00-sun:03:30"

  enabled_cloudwatch_logs_exports = [
    "postgresql",
    "upgrade",
  ]

  auto_minor_version_upgrade = true
  apply_immediately          = true
  copy_tags_to_snapshot      = true

  deletion_protection      = false
  skip_final_snapshot      = true
  delete_automated_backups = true

  tags = {
    Name = "${local.name_prefix}-postgresql"
    Tier = "data"
    Role = "relational-database"
  }
}
