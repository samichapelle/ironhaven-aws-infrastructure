resource "aws_cloudwatch_log_group" "management_system" {
  name              = "/ironhaven/management/system"
  retention_in_days = 7

  tags = {
    Name = "${local.name_prefix}-management-system-logs"
    Tier = "management"
  }
}

resource "aws_cloudwatch_log_group" "management_audit" {
  name              = "/ironhaven/management/audit"
  retention_in_days = 7

  tags = {
    Name = "${local.name_prefix}-management-audit-logs"
    Tier = "management"
  }
}

resource "aws_cloudwatch_log_group" "management_containers" {
  name              = "/ironhaven/management/containers"
  retention_in_days = 7

  tags = {
    Name = "${local.name_prefix}-management-container-logs"
    Tier = "management"
  }
}