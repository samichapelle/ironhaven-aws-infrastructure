resource "aws_security_group" "management" {
  name        = "${local.name_prefix}-management-sg"
  description = "Security group for the management and agent instance"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-management-sg"
    Tier = "management"
  }
}

resource "aws_security_group" "application" {
  name        = "${local.name_prefix}-application-sg"
  description = "Security group for internal application workloads"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-application-sg"
    Tier = "application"
  }
}

resource "aws_security_group" "data" {
  name        = "${local.name_prefix}-data-sg"
  description = "Security group for private data workloads"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-data-sg"
    Tier = "data"
  }
}

# Management tier: HTTPS access to AWS APIs and package repositories.

resource "aws_vpc_security_group_egress_rule" "management_https" {
  security_group_id = aws_security_group.management.id
  description       = "Allow HTTPS access to AWS APIs and repositories"

  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "management_dns_udp" {
  security_group_id = aws_security_group.management.id
  description       = "Allow UDP DNS resolution inside the VPC"

  ip_protocol = "udp"
  from_port   = 53
  to_port     = 53
  cidr_ipv4   = aws_vpc.main.cidr_block
}

resource "aws_vpc_security_group_egress_rule" "management_dns_tcp" {
  security_group_id = aws_security_group.management.id
  description       = "Allow TCP DNS resolution inside the VPC"

  ip_protocol = "tcp"
  from_port   = 53
  to_port     = 53
  cidr_ipv4   = aws_vpc.main.cidr_block
}

# Application tier: only the management tier can reach port 8080.

resource "aws_vpc_security_group_ingress_rule" "application_from_management" {
  security_group_id            = aws_security_group.application.id
  referenced_security_group_id = aws_security_group.management.id
  description                  = "Allow application traffic from management tier"

  ip_protocol = "tcp"
  from_port   = 8080
  to_port     = 8080
}

resource "aws_vpc_security_group_egress_rule" "application_https" {
  security_group_id = aws_security_group.application.id
  description       = "Allow HTTPS access for application dependencies"

  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "application_dns_udp" {
  security_group_id = aws_security_group.application.id
  description       = "Allow UDP DNS resolution inside the VPC"

  ip_protocol = "udp"
  from_port   = 53
  to_port     = 53
  cidr_ipv4   = aws_vpc.main.cidr_block
}

resource "aws_vpc_security_group_egress_rule" "application_dns_tcp" {
  security_group_id = aws_security_group.application.id
  description       = "Allow TCP DNS resolution inside the VPC"

  ip_protocol = "tcp"
  from_port   = 53
  to_port     = 53
  cidr_ipv4   = aws_vpc.main.cidr_block
}

resource "aws_vpc_security_group_egress_rule" "application_to_data" {
  security_group_id            = aws_security_group.application.id
  referenced_security_group_id = aws_security_group.data.id
  description                  = "Allow PostgreSQL traffic to the data tier"

  ip_protocol = "tcp"
  from_port   = 5432
  to_port     = 5432
}

# Data tier: only the application tier can initiate PostgreSQL connections.

resource "aws_vpc_security_group_ingress_rule" "data_from_application" {
  security_group_id            = aws_security_group.data.id
  referenced_security_group_id = aws_security_group.application.id
  description                  = "Allow PostgreSQL traffic from application tier"

  ip_protocol = "tcp"
  from_port   = 5432
  to_port     = 5432
}