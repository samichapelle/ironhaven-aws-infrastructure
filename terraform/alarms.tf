resource "aws_cloudwatch_metric_alarm" "application_cpu" {
  alarm_name          = "ironhaven-application-high-cpu"
  alarm_description   = "High CPU utilization on private application EC2"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "missing"

  dimensions = {
    InstanceId = aws_instance.application.id
  }

  tags = {
    Tier = "application"
  }
}

resource "aws_cloudwatch_metric_alarm" "management_cpu" {
  alarm_name          = "ironhaven-management-high-cpu"
  alarm_description   = "High CPU utilization on management EC2"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "missing"

  dimensions = {
    InstanceId = aws_instance.management.id
  }

  tags = {
    Tier = "management"
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_free_storage" {
  alarm_name          = "ironhaven-rds-low-free-storage"
  alarm_description   = "RDS PostgreSQL free storage below 2 GiB"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 2147483648
  treat_missing_data  = "missing"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.postgresql.identifier
  }

  tags = {
    Tier = "data"
  }
}
